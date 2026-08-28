import time
from typing import Dict, Any

class DeduplicationEngine:
    """
    In-memory cache to detect duplicate financial events.
    In a real production system, this would be Redis or a database.
    Since we don't own the DB (Member 2 does), we maintain our own sliding window cache.
    """
    def __init__(self, time_window_seconds: int = 300):
        # 5 minute window by default
        self.time_window_seconds = time_window_seconds
        # Structure: { hash_key: timestamp_added }
        self.cache: Dict[str, float] = {}

    def _generate_hash(self, event_data: Dict[str, Any]) -> str:
        """
        Creates a unique hash based on the core financial facts.
        If the amount, vendor, and type match exactly, it's likely a duplicate.
        Note: We lowercase the vendor and remove spaces for a fuzzy match.
        """
        vendor_normalized = event_data.get("vendor", "").lower().replace(" ", "")
        amount = event_data.get("amount", 0.0)
        event_type = event_data.get("type", "unknown")
        
        return f"{event_type}_{amount}_{vendor_normalized}"

    def is_duplicate(self, event_data: Dict[str, Any]) -> bool:
        """
        Checks if the event is a duplicate.
        Also cleans up expired items from the cache.
        """
        current_time = time.time()
        
        # Cleanup old entries
        self.cache = {k: v for k, v in self.cache.items() if current_time - v < self.time_window_seconds}
        
        event_hash = self._generate_hash(event_data)
        
        if event_hash in self.cache:
            return True
            
        # If not a duplicate, add to cache
        self.cache[event_hash] = current_time
        return False
