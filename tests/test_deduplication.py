"""Test message deduplication functionality."""

from unittest.mock import Mock

import pytest

from meshcore_mqtt.config import Config, ConnectionType, MeshCoreConfig, MQTTConfig
from meshcore_mqtt.meshcore_worker import MeshCoreWorker


class TestMessageDeduplication:
    """Test message deduplication in MeshCore worker."""

    @pytest.fixture
    def config(self) -> Config:
        """Create a test configuration."""
        return Config(
            meshcore=MeshCoreConfig(
                connection_type=ConnectionType.TCP,
                address="127.0.0.1",
                port=12345,
                events=["CONTACT_MSG_RECV"],
            ),
            mqtt=MQTTConfig(
                broker="localhost",
                port=1883,
                topic_prefix="test/meshcore",
            ),
        )

    @pytest.fixture
    def worker(self, config: Config) -> MeshCoreWorker:
        """Create a MeshCore worker for testing."""
        return MeshCoreWorker(config)

    def test_fingerprint_generation_message_events(
        self, worker: MeshCoreWorker
    ) -> None:
        """Test fingerprint generation for message events."""
        # Mock message event data
        mock_event = Mock()
        mock_event.type = "CONTACT_MSG_RECV"
        mock_event.payload = {
            "text": "Hello World",
            "from": "user123",
            "channel_idx": 0,
            "timestamp": 1627849200,
            "msg_id": "msg_123",
        }

        fingerprint1 = worker._generate_message_fingerprint(mock_event)
        fingerprint2 = worker._generate_message_fingerprint(mock_event)

        # Same event should generate same fingerprint
        assert fingerprint1 == fingerprint2
        assert len(fingerprint1) == 16  # MD5 hash truncated to 16 chars

    def test_fingerprint_generation_different_messages(
        self, worker: MeshCoreWorker
    ) -> None:
        """Test that different messages generate different fingerprints."""
        # Mock first message
        mock_event1 = Mock()
        mock_event1.type = "CONTACT_MSG_RECV"
        mock_event1.payload = {
            "text": "Hello World",
            "from": "user123",
        }

        # Mock second message (different text)
        mock_event2 = Mock()
        mock_event2.type = "CONTACT_MSG_RECV"
        mock_event2.payload = {
            "text": "Hello Universe",  # Different text
            "from": "user123",
        }

        fingerprint1 = worker._generate_message_fingerprint(mock_event1)
        fingerprint2 = worker._generate_message_fingerprint(mock_event2)

        assert fingerprint1 != fingerprint2

    def test_duplicate_detection(self, worker: MeshCoreWorker) -> None:
        """Test duplicate message detection."""
        fingerprint = "test123456789abc"

        # First message should not be duplicate
        assert not worker._is_duplicate_message(fingerprint)

        # Same fingerprint should now be duplicate
        assert worker._is_duplicate_message(fingerprint)

        # Different fingerprint should not be duplicate
        assert not worker._is_duplicate_message("different456789xyz")

    def test_cache_expiry(self, worker: MeshCoreWorker) -> None:
        """Test that old cache entries are expired."""
        import time

        fingerprint = "expire123456789"

        # Add message to cache
        assert not worker._is_duplicate_message(fingerprint)

        # Manually set old timestamp (simulate expired entry)
        worker._message_cache[fingerprint] = time.time() - 400  # 400 sec ago

        # Should not be duplicate after expiry
        assert not worker._is_duplicate_message(fingerprint)

    def test_cache_size_limit(self, worker: MeshCoreWorker) -> None:
        """Test that cache size is limited."""
        # Set small cache size for testing
        worker._cache_max_size = 3

        # Add messages up to limit + 2
        for i in range(6):
            fingerprint = f"msg{i:016d}"
            worker._is_duplicate_message(fingerprint)

        # Cache should not exceed max size after cleanup
        assert len(worker._message_cache) <= worker._cache_max_size

    def test_connection_events_not_deduplicated(self, worker: MeshCoreWorker) -> None:
        """Test that connection events are not subject to deduplication."""
        # Mock connection event
        mock_event = Mock()
        mock_event.type = "CONNECTED"
        mock_event.payload = {"status": "connected"}

        # Connection events should always have unique fingerprints
        # (because they're excluded from deduplication logic)
        fingerprint1 = worker._generate_message_fingerprint(mock_event)
        fingerprint2 = worker._generate_message_fingerprint(mock_event)

        # Even though fingerprints are same, connection events bypass deduplication
        assert fingerprint1 == fingerprint2

    def test_contact_event_enriched_from_recent_direct_rx_log(
        self, worker: MeshCoreWorker
    ) -> None:
        """CONTACT_MSG_RECV should gain RSSI/SNR from recent direct RX log."""
        rx_event = Mock()
        rx_event.payload = {
            "payload_type": 2,
            "rssi": -73,
            "snr": 12.0,
            "path": "",
            "recv_time": 1777770484,
        }

        contact_event = Mock()
        contact_event.payload = {
            "type": "PRIV",
            "pubkey_prefix": "c926de0b318c",
            "text": "Chicken",
            "SNR": 12.5,
        }

        worker._record_direct_rx_log(rx_event)
        worker._enrich_contact_event_with_direct_rx(contact_event)

        assert contact_event.payload["rssi"] == -73
        assert contact_event.payload["RSSI"] == -73
        # Preserve the event's explicit SNR while still offering lowercase alias.
        assert contact_event.payload["SNR"] == 12.5
        assert contact_event.payload["snr"] == 12.0
        assert contact_event.payload["recv_time"] == 1777770484

    def test_contact_event_enrichment_does_not_override_existing_rssi(
        self, worker: MeshCoreWorker
    ) -> None:
        """Existing contact RSSI should be preserved."""
        rx_event = Mock()
        rx_event.payload = {
            "payload_type": 2,
            "rssi": -88,
            "snr": 11.75,
            "path": "",
            "recv_time": 1777770500,
        }

        contact_event = Mock()
        contact_event.payload = {
            "type": "PRIV",
            "pubkey_prefix": "c926de0b318c",
            "text": "Chicken",
            "RSSI": -65,
            "SNR": 12.5,
        }

        worker._record_direct_rx_log(rx_event)
        worker._enrich_contact_event_with_direct_rx(contact_event)

        assert contact_event.payload["RSSI"] == -65
        assert contact_event.payload.get("rssi") is None
