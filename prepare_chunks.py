#!/usr/bin/env python3
"""
Prepare URL chunks for deployment
Splits URLs into chunks of 5000 each for distributed processing
"""

import os
import sys
import json
from pathlib import Path

def chunk_urls(urls_file, chunk_size=5000, output_dir='chunks'):
    """Split URLs file into chunks of specified size"""
    
    # Create output directory
    Path(output_dir).mkdir(exist_ok=True)
    
    # Read all URLs
    with open(urls_file, 'r') as f:
        urls = [line.strip() for line in f if line.strip()]
    
    total_urls = len(urls)
    num_chunks = (total_urls + chunk_size - 1) // chunk_size
    
    print(f"Total URLs: {total_urls}")
    print(f"Chunk size: {chunk_size}")
    print(f"Number of chunks: {num_chunks}")
    
    # Create chunks
    chunk_info = []
    for i in range(num_chunks):
        start_idx = i * chunk_size
        end_idx = min((i + 1) * chunk_size, total_urls)
        chunk_urls = urls[start_idx:end_idx]
        
        # Write chunk file
        chunk_filename = f"urls_chunk_{i+1:04d}.txt"
        chunk_path = os.path.join(output_dir, chunk_filename)
        
        with open(chunk_path, 'w') as f:
            for url in chunk_urls:
                f.write(url + '\n')
        
        chunk_info.append({
            'chunk_id': i + 1,
            'filename': chunk_filename,
            'url_count': len(chunk_urls),
            'start_index': start_idx,
            'end_index': end_idx
        })
        
        print(f"Created chunk {i+1}: {len(chunk_urls)} URLs")
    
    # Write chunk manifest
    manifest_path = os.path.join(output_dir, 'chunks_manifest.json')
    with open(manifest_path, 'w') as f:
        json.dump({
            'total_urls': total_urls,
            'chunk_size': chunk_size,
            'num_chunks': num_chunks,
            'chunks': chunk_info
        }, f, indent=2)
    
    print(f"\nChunk manifest saved to: {manifest_path}")
    return chunk_info

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python prepare_chunks.py <urls_file> [chunk_size] [output_dir]")
        print("Example: python prepare_chunks.py 1m-urls-1stdibs-raw.txt 5000 chunks")
        sys.exit(1)
    
    urls_file = sys.argv[1]
    chunk_size = int(sys.argv[2]) if len(sys.argv) > 2 else 5000
    output_dir = sys.argv[3] if len(sys.argv) > 3 else 'chunks'
    
    if not os.path.exists(urls_file):
        print(f"Error: URLs file '{urls_file}' not found")
        sys.exit(1)
    
    chunk_urls(urls_file, chunk_size, output_dir)