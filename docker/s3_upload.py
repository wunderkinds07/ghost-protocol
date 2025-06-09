#!/usr/bin/env python3
"""
Upload extracted data to S3 bucket
Run this after containers complete extraction
"""

import os
import json
import boto3
from pathlib import Path
from datetime import datetime
import logging
from tqdm import tqdm

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class S3Uploader:
    def __init__(self, bucket_name, aws_region='us-east-1'):
        self.bucket_name = bucket_name
        self.s3_client = boto3.client('s3', region_name=aws_region)
        
    def upload_container_data(self, container_id, local_data_path):
        """Upload all data from a container to S3"""
        container_path = Path(local_data_path)
        
        if not container_path.exists():
            logger.error(f"Container path not found: {container_path}")
            return False
        
        # Upload structure:
        # s3://bucket/1stdibs-extraction/container-X/raw_html/
        # s3://bucket/1stdibs-extraction/container-X/extracted/
        
        upload_stats = {'html': 0, 'json': 0, 'failed': 0}
        
        # Upload raw HTML files
        html_dir = container_path / 'raw_html'
        if html_dir.exists():
            html_files = list(html_dir.glob('*.html.gz'))
            logger.info(f"Uploading {len(html_files)} HTML files from container {container_id}")
            
            for html_file in tqdm(html_files, desc=f"Container {container_id} HTML"):
                s3_key = f"1stdibs-extraction/container-{container_id}/raw_html/{html_file.name}"
                try:
                    self.s3_client.upload_file(
                        str(html_file), 
                        self.bucket_name, 
                        s3_key,
                        ExtraArgs={'ContentType': 'application/gzip'}
                    )
                    upload_stats['html'] += 1
                except Exception as e:
                    logger.error(f"Failed to upload {html_file}: {e}")
                    upload_stats['failed'] += 1
        
        # Upload extracted JSON files
        json_dir = container_path / 'extracted'
        if json_dir.exists():
            json_files = list(json_dir.glob('*.json'))
            logger.info(f"Uploading {len(json_files)} JSON files from container {container_id}")
            
            for json_file in tqdm(json_files, desc=f"Container {container_id} JSON"):
                s3_key = f"1stdibs-extraction/container-{container_id}/extracted/{json_file.name}"
                try:
                    self.s3_client.upload_file(
                        str(json_file), 
                        self.bucket_name, 
                        s3_key,
                        ExtraArgs={'ContentType': 'application/json'}
                    )
                    upload_stats['json'] += 1
                except Exception as e:
                    logger.error(f"Failed to upload {json_file}: {e}")
                    upload_stats['failed'] += 1
        
        # Upload summary and logs
        for summary_file in container_path.glob('*.json'):
            s3_key = f"1stdibs-extraction/container-{container_id}/{summary_file.name}"
            try:
                self.s3_client.upload_file(
                    str(summary_file), 
                    self.bucket_name, 
                    s3_key
                )
            except Exception as e:
                logger.error(f"Failed to upload {summary_file}: {e}")
        
        return upload_stats
    
    def upload_all_containers(self, base_data_dir='./data'):
        """Upload data from all containers"""
        data_path = Path(base_data_dir)
        container_dirs = sorted([d for d in data_path.iterdir() if d.is_dir() and d.name.startswith('container')])
        
        logger.info(f"Found {len(container_dirs)} container directories")
        
        total_stats = {'html': 0, 'json': 0, 'failed': 0}
        
        for container_dir in container_dirs:
            container_id = container_dir.name.replace('container', '')
            logger.info(f"\nProcessing container {container_id}")
            
            stats = self.upload_container_data(container_id, container_dir)
            total_stats['html'] += stats['html']
            total_stats['json'] += stats['json']
            total_stats['failed'] += stats['failed']
        
        # Create and upload master summary
        master_summary = {
            'upload_time': datetime.now().isoformat(),
            'total_containers': len(container_dirs),
            'total_html_files': total_stats['html'],
            'total_json_files': total_stats['json'],
            'failed_uploads': total_stats['failed'],
            'bucket': self.bucket_name
        }
        
        summary_path = Path('/tmp/upload_summary.json')
        with open(summary_path, 'w') as f:
            json.dump(master_summary, f, indent=2)
        
        self.s3_client.upload_file(
            str(summary_path),
            self.bucket_name,
            '1stdibs-extraction/upload_summary.json'
        )
        
        logger.info("\n" + "="*50)
        logger.info("Upload Complete!")
        logger.info(f"HTML files uploaded: {total_stats['html']}")
        logger.info(f"JSON files uploaded: {total_stats['json']}")
        logger.info(f"Failed uploads: {total_stats['failed']}")
        logger.info(f"S3 location: s3://{self.bucket_name}/1stdibs-extraction/")

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Upload 1stDibs extraction data to S3')
    parser.add_argument('--bucket', required=True, help='S3 bucket name')
    parser.add_argument('--region', default='us-east-1', help='AWS region')
    parser.add_argument('--data-dir', default='./data', help='Local data directory')
    
    args = parser.parse_args()
    
    uploader = S3Uploader(args.bucket, args.region)
    uploader.upload_all_containers(args.data_dir)