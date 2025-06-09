#!/usr/bin/env python3
"""
Simple notification system for container progress updates.
Supports multiple notification methods without complex setup.
"""

import os
import json
import requests
from datetime import datetime
from typing import Dict, Any, Optional
import socket
import logging

logger = logging.getLogger(__name__)


class SimpleNotifier:
    """Send notifications through various simple channels"""
    
    def __init__(self):
        self.container_id = os.environ.get('CONTAINER_ID', 'unknown')
        self.hostname = socket.gethostname()
        
        # Check which notification methods are configured
        self.webhook_url = os.environ.get('WEBHOOK_URL')
        self.pushover_token = os.environ.get('PUSHOVER_APP_TOKEN')
        self.pushover_user = os.environ.get('PUSHOVER_USER_KEY')
        self.telegram_token = os.environ.get('TELEGRAM_BOT_TOKEN')
        self.telegram_chat = os.environ.get('TELEGRAM_CHAT_ID')
        self.ntfy_topic = os.environ.get('NTFY_TOPIC', 'callofdutyblackopsghostprotocolbravo64')
        self.discord_webhook = os.environ.get('DISCORD_WEBHOOK')
        self.slack_webhook = os.environ.get('SLACK_WEBHOOK')
        
    def notify(self, stage: str, message: str, data: Optional[Dict[str, Any]] = None):
        """Send notification through all configured channels"""
        
        notification = {
            'container_id': self.container_id,
            'hostname': self.hostname,
            'timestamp': datetime.utcnow().isoformat(),
            'stage': stage,
            'message': message,
            'data': data or {}
        }
        
        # Try each configured notification method
        methods_tried = 0
        
        if self.webhook_url:
            self._send_webhook(notification)
            methods_tried += 1
            
        if self.pushover_token and self.pushover_user:
            self._send_pushover(notification)
            methods_tried += 1
            
        if self.telegram_token and self.telegram_chat:
            self._send_telegram(notification)
            methods_tried += 1
            
        if self.ntfy_topic:
            self._send_ntfy(notification)
            methods_tried += 1
            
        if self.discord_webhook:
            self._send_discord(notification)
            methods_tried += 1
            
        if self.slack_webhook:
            self._send_slack(notification)
            methods_tried += 1
        
        # Always log locally
        logger.info(f"[{stage}] {message}")
        
        if methods_tried == 0:
            logger.debug("No notification methods configured")
    
    def _send_webhook(self, notification: Dict):
        """Generic webhook (JSON POST)"""
        try:
            response = requests.post(
                self.webhook_url,
                json=notification,
                timeout=5
            )
            response.raise_for_status()
        except Exception as e:
            logger.error(f"Webhook notification failed: {e}")
    
    def _send_pushover(self, notification: Dict):
        """Pushover notification (mobile push)"""
        try:
            data = {
                'token': self.pushover_token,
                'user': self.pushover_user,
                'title': f'Container {self.container_id}',
                'message': f"{notification['stage']}: {notification['message']}",
                'priority': 0 if notification['stage'] != 'error' else 1
            }
            response = requests.post(
                'https://api.pushover.net/1/messages.json',
                data=data,
                timeout=5
            )
            response.raise_for_status()
        except Exception as e:
            logger.error(f"Pushover notification failed: {e}")
    
    def _send_telegram(self, notification: Dict):
        """Telegram bot notification"""
        try:
            text = f"🐳 *Container {self.container_id}*\n"
            text += f"📍 Stage: {notification['stage']}\n"
            text += f"💬 {notification['message']}\n"
            
            if notification['data']:
                text += f"📊 Data: `{json.dumps(notification['data'], indent=2)}`"
            
            response = requests.post(
                f'https://api.telegram.org/bot{self.telegram_token}/sendMessage',
                json={
                    'chat_id': self.telegram_chat,
                    'text': text,
                    'parse_mode': 'Markdown'
                },
                timeout=5
            )
            response.raise_for_status()
        except Exception as e:
            logger.error(f"Telegram notification failed: {e}")
    
    def _send_ntfy(self, notification: Dict):
        """ntfy.sh notification (simple pub/sub)"""
        try:
            headers = {
                'Title': f'Container {self.container_id}',
                'Priority': 'default',
                'Tags': notification['stage']
            }
            
            response = requests.post(
                f'https://ntfy.sh/{self.ntfy_topic}',
                data=notification['message'],
                headers=headers,
                timeout=5
            )
            response.raise_for_status()
        except Exception as e:
            logger.error(f"ntfy notification failed: {e}")
    
    def _send_discord(self, notification: Dict):
        """Discord webhook notification"""
        try:
            embed = {
                'title': f'Container {self.container_id}',
                'description': notification['message'],
                'color': self._get_color_for_stage(notification['stage']),
                'fields': [
                    {'name': 'Stage', 'value': notification['stage'], 'inline': True},
                    {'name': 'Time', 'value': notification['timestamp'], 'inline': True}
                ]
            }
            
            if notification['data']:
                for key, value in notification['data'].items():
                    embed['fields'].append({
                        'name': key.replace('_', ' ').title(),
                        'value': str(value),
                        'inline': True
                    })
            
            response = requests.post(
                self.discord_webhook,
                json={'embeds': [embed]},
                timeout=5
            )
            response.raise_for_status()
        except Exception as e:
            logger.error(f"Discord notification failed: {e}")
    
    def _send_slack(self, notification: Dict):
        """Slack webhook notification"""
        try:
            blocks = [
                {
                    'type': 'header',
                    'text': {
                        'type': 'plain_text',
                        'text': f'Container {self.container_id}'
                    }
                },
                {
                    'type': 'section',
                    'text': {
                        'type': 'mrkdwn',
                        'text': f"*Stage:* {notification['stage']}\n*Message:* {notification['message']}"
                    }
                }
            ]
            
            if notification['data']:
                fields = []
                for key, value in notification['data'].items():
                    fields.append({
                        'type': 'mrkdwn',
                        'text': f"*{key}:* {value}"
                    })
                blocks.append({
                    'type': 'section',
                    'fields': fields
                })
            
            response = requests.post(
                self.slack_webhook,
                json={'blocks': blocks},
                timeout=5
            )
            response.raise_for_status()
        except Exception as e:
            logger.error(f"Slack notification failed: {e}")
    
    def _get_color_for_stage(self, stage: str) -> int:
        """Get color code for Discord embeds"""
        colors = {
            'started': 0x3498db,    # Blue
            'progress': 0xf39c12,   # Orange
            'completed': 0x27ae60,  # Green
            'error': 0xe74c3c,      # Red
            'warning': 0xf1c40f     # Yellow
        }
        return colors.get(stage, 0x95a5a6)  # Default gray


# Convenience functions for direct use
_notifier = None

def get_notifier() -> SimpleNotifier:
    """Get or create notifier instance"""
    global _notifier
    if _notifier is None:
        _notifier = SimpleNotifier()
    return _notifier

def notify_start(total_urls: int):
    """Notify container started"""
    get_notifier().notify(
        'started',
        f'Container started processing {total_urls} URLs',
        {'total_urls': total_urls}
    )

def notify_progress(processed: int, total: int, success: int, failed: int):
    """Notify progress update"""
    progress_pct = (processed / total * 100) if total > 0 else 0
    get_notifier().notify(
        'progress',
        f'Progress: {processed}/{total} ({progress_pct:.1f}%)',
        {
            'processed': processed,
            'total': total,
            'success': success,
            'failed': failed,
            'progress_percent': round(progress_pct, 1)
        }
    )

def notify_milestone(milestone: int):
    """Notify milestone reached"""
    get_notifier().notify(
        'progress',
        f'Milestone reached: {milestone} URLs processed',
        {'milestone': milestone}
    )

def notify_complete(stats: Dict[str, Any]):
    """Notify container completed"""
    get_notifier().notify(
        'completed',
        f'Container completed: {stats.get("successful", 0)} successful, {stats.get("failed", 0)} failed',
        stats
    )

def notify_error(error_msg: str, error_data: Optional[Dict] = None):
    """Notify error occurred"""
    get_notifier().notify(
        'error',
        f'Error: {error_msg}',
        error_data
    )

def notify_warning(warning_msg: str, warning_data: Optional[Dict] = None):
    """Notify warning"""
    get_notifier().notify(
        'warning',
        f'Warning: {warning_msg}',
        warning_data
    )