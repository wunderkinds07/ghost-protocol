#!/usr/bin/env python3
"""
S3 uploader for extracted data
Uploads completed files to S3 bucket
"""

import os
import boto3
import json
from pathlib import Path
import logging
from datetime import datetime

logger = logging.getLogger(__name__)

class S3Uploader:
    def __init__(self):
        self.bucket_name = os.environ.get('S3_BUCKET')
        self.container_id = os.environ.get('CONTAINER_ID', 'unknown')
        self.region = os.environ.get('AWS_DEFAULT_REGION', 'us-east-1')
        
        if self.bucket_name:
            self.s3_client = boto3.client('s3', region_name=self.region)
            self.enabled = True
            logger.info(f"S3 uploader initialized for bucket: {self.bucket_name}")
        else:
            self.enabled = False
            logger.info("S3 uploader disabled (no S3_BUCKET environment variable)")
    
    def upload_file(self, local_path: Path, s3_key: str):
        """Upload a single file to S3"""
        if not self.enabled:
            return False
        
        try:
            # Add container prefix to S3 key
            full_s3_key = f"containers/{self.container_id}/{s3_key}"
            
            # Upload file
            self.s3_client.upload_file(
                str(local_path),
                self.bucket_name,
                full_s3_key,
                ExtraArgs={
                    'Metadata': {
                        'container_id': self.container_id,
                        'upload_time': datetime.utcnow().isoformat()
                    }
                }
            )
            
            logger.info(f"Uploaded {local_path} to s3://{self.bucket_name}/{full_s3_key}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to upload {local_path} to S3: {str(e)}")
            return False
    
    def upload_extracted_data(self, product_id: str, json_path: Path):
        """Upload extracted JSON data to S3"""
        if not self.enabled:
            return
        
        s3_key = f"extracted/{product_id}.json"
        self.upload_file(json_path, s3_key)
    
    def upload_raw_html(self, product_id: str, html_path: Path):
        """Upload compressed HTML to S3"""
        if not self.enabled:
            return
        
        s3_key = f"raw_html/{product_id}.html.gz"
        self.upload_file(html_path, s3_key)
    
    def upload_summary(self, summary_path: Path):
        """Upload container summary to S3"""
        if not self.enabled:
            return
        
        s3_key = f"summaries/container_{self.container_id}_summary.json"
        self.upload_file(summary_path, s3_key)
    
    def batch_upload_directory(self, local_dir: Path, s3_prefix: str):
        """Upload entire directory to S3"""
        if not self.enabled:
            return
        
        uploaded = 0
        failed = 0
        
        for file_path in local_dir.glob('**/*'):
            if file_path.is_file():
                relative_path = file_path.relative_to(local_dir)
                s3_key = f"{s3_prefix}/{relative_path}"
                
                if self.upload_file(file_path, s3_key):
                    uploaded += 1
                else:
                    failed += 1
        
        logger.info(f"Batch upload complete: {uploaded} succeeded, {failed} failed")
        return uploaded, failed


# Singleton instance
_s3_uploader = None

def get_s3_uploader():
    """Get or create S3 uploader instance"""
    global _s3_uploader
    if _s3_uploader is None:
        _s3_uploader = S3Uploader()
    return _s3_uploader