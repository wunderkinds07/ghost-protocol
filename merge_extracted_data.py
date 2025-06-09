#!/usr/bin/env python3
"""
Merge all extracted JSON data from multiple instances/chunks
"""

import os
import sys
import json
import glob
from pathlib import Path
from collections import defaultdict

def merge_extracted_data(results_dir, output_file='merged_products.json'):
    """Merge all extracted product data from collection directory"""
    
    all_products = []
    stats = defaultdict(int)
    
    # Find all extracted JSON files
    json_files = glob.glob(os.path.join(results_dir, '**/extracted/*.json'), recursive=True)
    
    print(f"Found {len(json_files)} extracted product files")
    
    for json_file in json_files:
        try:
            with open(json_file, 'r') as f:
                data = json.load(f)
                
            # Extract product info
            if isinstance(data, dict):
                all_products.append(data)
                
                # Collect stats
                if 'category' in data:
                    stats['categories'][data['category']] += 1
                if 'price' in data and data['price']:
                    stats['with_price'] += 1
                if 'materials' in data and data['materials']:
                    stats['with_materials'] += 1
                    
        except Exception as e:
            print(f"Error reading {json_file}: {e}")
            stats['errors'] += 1
    
    # Save merged data
    with open(output_file, 'w') as f:
        json.dump({
            'total_products': len(all_products),
            'products': all_products,
            'statistics': dict(stats)
        }, f, indent=2)
    
    print(f"\nMerged {len(all_products)} products to {output_file}")
    print(f"Products with price: {stats['with_price']}")
    print(f"Products with materials: {stats['with_materials']}")
    print(f"Errors: {stats['errors']}")
    
    return all_products

def create_analysis_summary(results_dir, output_file='analysis_summary.json'):
    """Create comprehensive analysis summary"""
    
    summary = {
        'chunks_processed': 0,
        'instances_used': 0,
        'total_urls_processed': 0,
        'successful_extractions': 0,
        'failed_extractions': 0,
        'category_distribution': defaultdict(int),
        'price_ranges': {
            'under_1000': 0,
            '1000_5000': 0,
            '5000_10000': 0,
            '10000_50000': 0,
            'over_50000': 0,
            'no_price': 0
        }
    }
    
    # Count instances and chunks
    instance_dirs = glob.glob(os.path.join(results_dir, 'instance_*'))
    summary['instances_used'] = len(instance_dirs)
    
    chunk_dirs = glob.glob(os.path.join(results_dir, '**/chunk_*'), recursive=True)
    summary['chunks_processed'] = len(chunk_dirs)
    
    # Analyze products
    json_files = glob.glob(os.path.join(results_dir, '**/extracted/*.json'), recursive=True)
    summary['successful_extractions'] = len(json_files)
    
    for json_file in json_files:
        try:
            with open(json_file, 'r') as f:
                product = json.load(f)
            
            # Category analysis
            if 'category' in product:
                summary['category_distribution'][product['category']] += 1
            
            # Price analysis
            if 'price' in product and product['price']:
                try:
                    price = float(product['price'].replace('$', '').replace(',', ''))
                    if price < 1000:
                        summary['price_ranges']['under_1000'] += 1
                    elif price < 5000:
                        summary['price_ranges']['1000_5000'] += 1
                    elif price < 10000:
                        summary['price_ranges']['5000_10000'] += 1
                    elif price < 50000:
                        summary['price_ranges']['10000_50000'] += 1
                    else:
                        summary['price_ranges']['over_50000'] += 1
                except:
                    summary['price_ranges']['no_price'] += 1
            else:
                summary['price_ranges']['no_price'] += 1
                
        except Exception as e:
            print(f"Error analyzing {json_file}: {e}")
    
    # Convert defaultdict to regular dict for JSON serialization
    summary['category_distribution'] = dict(summary['category_distribution'])
    
    # Save summary
    with open(output_file, 'w') as f:
        json.dump(summary, f, indent=2)
    
    print(f"\nAnalysis summary saved to {output_file}")
    
    # Print summary
    print("\n=== Processing Summary ===")
    print(f"Instances used: {summary['instances_used']}")
    print(f"Chunks processed: {summary['chunks_processed']}")
    print(f"Successful extractions: {summary['successful_extractions']}")
    print(f"\nTop categories:")
    for category, count in sorted(summary['category_distribution'].items(), 
                                 key=lambda x: x[1], reverse=True)[:10]:
        print(f"  {category}: {count}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python merge_extracted_data.py <results_directory> [output_file]")
        sys.exit(1)
    
    results_dir = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else 'merged_products.json'
    
    if not os.path.exists(results_dir):
        print(f"Error: Results directory '{results_dir}' not found")
        sys.exit(1)
    
    # Merge data
    merge_extracted_data(results_dir, output_file)
    
    # Create analysis summary
    create_analysis_summary(results_dir, 'analysis_summary.json')