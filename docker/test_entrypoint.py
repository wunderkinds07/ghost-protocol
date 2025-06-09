#!/usr/bin/env python3
"""Test version with embedded test URLs"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Import the main processor
from docker.entrypoint import ContainerProcessor

# Override the load_urls method for testing
class TestContainerProcessor(ContainerProcessor):
    def load_urls(self):
        """Load test URLs"""
        test_urls = [
            "https://www.1stdibs.com/furniture/decorative-objects/vases-vessels/vases/oversized-floor-standing-murano-glass-vase-flavio-poli-seguso-italy-1960/id-f_36610525/",
            "https://www.1stdibs.com/furniture/tables/coffee-tables-cocktail-tables/modern-walnut-coffee-table-asymmetric-legs-1950s/id-f_29876543/",
            "https://www.1stdibs.com/furniture/mirrors/wall-mirrors/italian-baroque-giltwood-mirror-18th-century/id-f_18765432/",
            "https://www.1stdibs.com/furniture/seating/chairs/set-of-six-danish-modern-dining-chairs-teak-1960s/id-f_24567890/",
            "https://www.1stdibs.com/furniture/lighting/chandeliers-pendant-lights/murano-glass-chandelier-venini-style-1970s/id-f_31234567/"
        ]
        
        # Only return URLs for this container's chunk
        start = self.chunk_start
        end = min(start + self.chunk_size, len(test_urls))
        urls = test_urls[start:end]
        
        print(f"Test mode: Loaded {len(urls)} test URLs")
        return urls

if __name__ == "__main__":
    # Set test environment
    os.environ['CONTAINER_ID'] = os.environ.get('CONTAINER_ID', 'test-1')
    os.environ['URL_CHUNK_START'] = '0'
    os.environ['URL_CHUNK_SIZE'] = '5'
    
    processor = TestContainerProcessor()
    processor.run()