# Technical Specification: 1stDibs Data Extraction Pipeline

## 1. Data Extraction Specifications

### 1.1 Extracted Data Fields - Detailed Breakdown

#### Product Information
```json
{
  "product_info": {
    "title": {
      "type": "string",
      "source": "JSON-LD @type=Product name field",
      "fallback": "<h1> tag with class 'headline-3'",
      "example": "Italian Parcel Ebonized Walnut Mirror, 18th Century",
      "max_length": 500
    },
    "product_id": {
      "type": "string",
      "source": "URL pattern /id-f_XXXXX/",
      "validation": "^f_[0-9]+$",
      "example": "f_10001073",
      "required": true
    },
    "description": {
      "type": "string",
      "source": "JSON-LD description field",
      "processing": "Strip HTML tags, normalize whitespace",
      "example": "An Italian parcel ebonized walnut mirror...",
      "max_length": 5000
    },
    "brand": {
      "type": "string",
      "source": "JSON-LD brand.name",
      "example": "Charles Eames",
      "nullable": true
    },
    "availability": {
      "type": "string",
      "source": "JSON-LD offers[0].availability",
      "values": ["http://schema.org/InStock", "http://schema.org/OutOfStock"],
      "processing": "Remove schema.org prefix"
    }
  }
}
```

#### Specifications
```json
{
  "specifications": {
    "period": {
      "type": "string",
      "source": "JSON-LD productionDate",
      "examples": ["18th Century", "1960s", "Contemporary"],
      "validation": "Century or decade format"
    },
    "category": {
      "type": "string",
      "source": "JSON-LD category field",
      "examples": ["Dining Room Sets", "Wall Mirrors", "Table Lamps"],
      "hierarchy": "Extracted from breadcrumb"
    },
    "condition": {
      "type": "string",
      "source": "JSON-LD itemCondition",
      "values": ["NewCondition", "UsedCondition", "RefurbishedCondition"],
      "processing": "Remove 'Condition' suffix"
    },
    "dimensions": {
      "type": "object",
      "source": "Regex extraction from description",
      "pattern": "Height\\s*([\\d\\s/]+)\\s*x\\s*width\\s*([\\d\\s/]+)",
      "structure": {
        "height": "string with unit",
        "width": "string with unit",
        "depth": "string with unit (optional)"
      },
      "example": {
        "height": "34 1/2 inches",
        "width": "48 inches",
        "depth": "3 inches"
      }
    },
    "materials": {
      "type": "string",
      "source": "Description text analysis",
      "keywords": ["walnut", "oak", "brass", "marble", "glass", "ceramic"],
      "processing": "Extract and capitalize material keywords",
      "example": "Walnut, Brass"
    },
    "style": {
      "type": "string",
      "source": "HTML parsing or description",
      "examples": ["Mid-Century Modern", "Art Deco", "Contemporary"],
      "nullable": true
    },
    "origin": {
      "type": "string",
      "source": "Description or metadata",
      "examples": ["Italy", "France", "United States"],
      "nullable": true
    }
  }
}
```

#### Pricing Structure
```json
{
  "pricing": {
    "currency": {
      "type": "string",
      "source": "Primary currency from offers",
      "default": "USD",
      "format": "ISO 4217"
    },
    "price": {
      "type": "string",
      "source": "JSON-LD offers with USD currency",
      "format": "Numeric string without symbols",
      "example": "5400"
    },
    "multi_currency": {
      "type": "object",
      "source": "All offers in JSON-LD array",
      "structure": {
        "USD": "number",
        "EUR": "number",
        "GBP": "number",
        "CAD": "number",
        "AUD": "number",
        "CHF": "number",
        "SEK": "number",
        "NOK": "number",
        "DKK": "number",
        "MXN": "number"
      },
      "example": {
        "USD": 5400,
        "EUR": 4814.55,
        "GBP": 4058.31
      }
    }
  }
}
```

#### Image Data
```json
{
  "images": {
    "type": "array",
    "source": "JSON-LD image array",
    "processing": "Extract contentUrl, remove query parameters",
    "structure": ["string"],
    "example": [
      "https://a.1stdibscdn.com/.../10001073_master.jpg",
      "https://a.1stdibscdn.com/.../IMG_8169_master.jpg"
    ],
    "validation": "Must be absolute URLs",
    "average_count": 9,
    "max_count": 20
  }
}
```

### 1.2 HTML Structure Analysis

#### JSON-LD Script Location
```html
<script data-react-helmet="true" type="application/ld+json">
[
  {
    "@context": "http://schema.org",
    "@type": "Product",
    "name": "Product Title",
    "offers": [/* Multi-currency offers */],
    "image": [/* Array of ImageObject */],
    "category": "Category Name",
    "productionDate": "18th Century"
  },
  {
    "@context": "http://schema.org",
    "@type": "BreadcrumbList",
    "itemListElement": [/* Breadcrumb items */]
  }
]
</script>
```

#### Key HTML Elements
```html
<!-- Product Title -->
<h1 class="headline-3">Product Title</h1>

<!-- Price Display -->
<span data-cy="price-USD">$5,400</span>
<span data-cy="price-EUR">€4,831</span>

<!-- Product Details -->
<div class="product-details">
  <li>Materials and Techniques: Walnut</li>
  <li>Place of Origin: Italy</li>
  <li>Period: 18th Century</li>
  <li>Condition: Good</li>
</div>

<!-- Breadcrumb -->
<nav aria-label="breadcrumb">
  <a href="/">Home</a>
  <a href="/furniture/">Furniture</a>
  <a href="/furniture/mirrors/">Mirrors</a>
</nav>
```

---

## 2. System Architecture - Detailed Components

### 2.1 Container Lifecycle

```
Container Start
     │
     ▼
┌─────────────────────┐
│ Environment Setup   │
│ - Load env vars     │
│ - Create directories│
│ - Setup logging     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ URL Loading         │
│ - Read chunk file   │
│ - Validate URLs     │
│ - Count total       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Processing Loop     │
│ ┌─────────────────┐ │
│ │ For each URL:   │ │
│ │ - Extract ID    │ │
│ │ - Fetch HTML    │ │
│ │ - Save HTML     │ │
│ │ - Extract data  │ │
│ │ - Save JSON     │ │
│ │ - Update stats  │ │
│ └─────────────────┘ │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Summary Generation  │
│ - Calculate stats   │
│ - Save summary JSON │
│ - Log completion    │
└─────────────────────┘
```

### 2.2 Error Handling Matrix

| Error Type | Response | Retry Logic | Logging |
|------------|----------|-------------|---------|
| Connection Error | Retry 3x | Exponential backoff 4-10s | ERROR level |
| 404 Not Found | Skip | No retry | WARN level |
| 429 Rate Limit | Delay | Increase delay by 50% | WARN level |
| 500 Server Error | Retry 3x | Fixed 10s delay | ERROR level |
| Timeout (30s) | Retry 2x | No delay | WARN level |
| Parse Error | Skip | No retry | ERROR level |
| Disk Full | Abort | N/A | CRITICAL level |

### 2.3 Performance Optimization

#### Parallel Processing
```python
def fetch_html_batch(self, urls: List[str]) -> List[RawHTMLData]:
    with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
        # Submit all tasks
        future_to_url = {
            executor.submit(self.fetch_single_html, url): url 
            for url in urls
        }
        
        # Collect results with progress bar
        results = []
        for future in tqdm(as_completed(future_to_url), total=len(urls)):
            result = future.result()
            results.append(result)
```

#### Memory Management
```python
# Process in chunks to avoid memory overflow
CHUNK_SIZE = 100
for i in range(0, len(urls), CHUNK_SIZE):
    chunk = urls[i:i + CHUNK_SIZE]
    process_chunk(chunk)
    
    # Force garbage collection every 1000 URLs
    if i % 1000 == 0:
        gc.collect()
```

#### I/O Optimization
```python
# Batch write operations
def save_batch(self, results: List[Dict], batch_size=50):
    for i in range(0, len(results), batch_size):
        batch = results[i:i + batch_size]
        
        # Single transaction for multiple writes
        with open('batch_output.json', 'a') as f:
            for item in batch:
                f.write(json.dumps(item) + '\n')
```

---

## 3. Deployment Configurations

### 3.1 Environment Variables Reference

| Variable | Description | Default | Valid Range |
|----------|-------------|---------|-------------|
| CONTAINER_ID | Unique container name | "1" | Any string |
| CHUNK_NAME | Same as CONTAINER_ID | "1" | Any string |
| URL_CHUNK_START | Starting index | "0" | 0-999999999 |
| URL_CHUNK_SIZE | URLs to process | "5000" | 1-50000 |
| MAX_WORKERS | Parallel threads | "4" | 1-10 |
| DELAY_MIN | Min delay (seconds) | "0.5" | 0.1-10 |
| DELAY_MAX | Max delay (seconds) | "1.0" | 0.5-20 |
| RETRY_ATTEMPTS | Retry count | "3" | 1-5 |
| TIMEOUT | Request timeout | "30" | 10-120 |
| LOG_LEVEL | Logging verbosity | "INFO" | DEBUG/INFO/WARN/ERROR |

### 3.2 Resource Allocation Guidelines

#### Container Sizing
| URLs | CPU | Memory | Storage | Est. Time |
|------|-----|---------|----------|-----------|
| 1,000 | 0.5 | 512MB | 200MB | 25 min |
| 5,000 | 1.0 | 1GB | 1GB | 2 hours |
| 10,000 | 1.5 | 1.5GB | 2GB | 4 hours |
| 50,000 | 2.0 | 2GB | 10GB | 20 hours |

#### Network Bandwidth
```
Per URL bandwidth calculation:
- Download HTML: ~1MB (average)
- Upload to S3: ~200KB (compressed)
- Total: ~1.2MB per URL

For 5,000 URLs:
- Download: 5GB
- Upload: 1GB
- Duration: 2 hours
- Average bandwidth: 8.3 Mbps
```

### 3.3 Container Naming Scheme

#### Name Categories Distribution
```python
naming_distribution = {
    "military_alphabet": 26,    # alpha through zulu
    "space_missions": 15,       # apollo, gemini, mercury...
    "mythology": 25,           # phoenix, dragon, griffin...
    "animals": 30,             # eagle, tiger, cobra...
    "gemstones": 20,           # ruby, diamond, emerald...
    "elements": 15,            # gold, silver, titanium...
    "weather": 20,             # tornado, aurora, tempest...
    "geography": 25,           # canyon, glacier, tundra...
    "astronomy": 20,           # nebula, quasar, pulsar...
    "vehicles": 12,            # gallardo, aventador...
    "fruits": 20,              # mango, pineapple...
    "abstract": 22             # vertex, nexus, cipher...
}
# Total: 250 unique names
```

#### Naming Convention Rules
1. All lowercase
2. Single word only
3. ASCII characters only
4. 3-10 characters length
5. No numbers or special characters
6. Memorable and pronounceable

---

## 4. Data Storage Specifications

### 4.1 File System Layout

```
data/
└── phoenix/                          # Container name
    ├── raw_html/                    # Compressed HTML storage
    │   ├── f_10001073.html.gz      # Size: ~200KB
    │   ├── f_10001074.html.gz
    │   └── ... (5,000 files)
    │
    ├── extracted/                   # JSON data files
    │   ├── f_10001073.json         # Size: ~3KB
    │   ├── f_10001074.json
    │   └── ... (5,000 files)
    │
    ├── logs/                        # Processing logs
    │   └── extraction.log          # Rotating, max 100MB
    │
    ├── container_phoenix_summary.json   # Final summary
    ├── container_phoenix_checkpoint.json # Progress checkpoint
    └── failed_urls.txt             # Failed URL list
```

### 4.2 File Formats

#### Raw HTML Storage (.html.gz)
```python
# Compression settings
COMPRESSION_LEVEL = 6  # Balanced speed vs size
ENCODING = 'utf-8'

# File header (first 4 bytes)
# 1f 8b 08 00  # gzip magic number
```

#### Extracted JSON Format
```json
{
  "url": "https://www.1stdibs.com/...",
  "extraction_status": "success",
  "data": {
    "product_info": {},
    "specifications": {},
    "pricing": {},
    "images": [],
    "category_breadcrumb": []
  },
  "extraction_metadata": {
    "container_id": "phoenix",
    "extraction_time": "2024-01-15T10:30:45.123456",
    "html_size_bytes": 1048576,
    "extraction_duration_ms": 523,
    "product_id": "f_10001073",
    "extractor_version": "1.0.0"
  }
}
```

#### Summary JSON Format
```json
{
  "container_id": "phoenix",
  "chunk_name": "phoenix",
  "processing_time": "2024-01-15T12:45:30.123456",
  "urls_processed": 5000,
  "successful": 4950,
  "failed": 50,
  "chunk_range": "10000-15000",
  "success_rate": "99.0%",
  "elapsed_seconds": 7234.56,
  "urls_per_minute": 41.5,
  "average_html_size_bytes": 205234,
  "total_storage_used_mb": 1024.5,
  "error_breakdown": {
    "404": 30,
    "timeout": 15,
    "parse_error": 5
  },
  "performance_metrics": {
    "avg_fetch_time_ms": 1523,
    "avg_extract_time_ms": 234,
    "avg_total_time_ms": 1891
  }
}
```

### 4.3 Data Integrity

#### Checksums
```python
def calculate_checksum(file_path):
    """Calculate SHA-256 checksum for data integrity"""
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()
```

#### Validation Rules
```python
def validate_json_output(json_file):
    """Validate extracted JSON meets requirements"""
    with open(json_file, 'r') as f:
        data = json.load(f)
    
    # Required fields
    assert 'product_info' in data['data']
    assert 'product_id' in data['data']['product_info']
    assert data['data']['product_info']['product_id'].startswith('f_')
    
    # Data types
    assert isinstance(data['data']['images'], list)
    assert isinstance(data['data']['pricing'], dict)
    
    # Business rules
    assert len(data['data']['images']) <= 20
    assert 0 < float(data['data']['pricing'].get('price', 0)) < 10000000
```

---

## 5. Network and API Specifications

### 5.1 HTTP Request Configuration

```python
REQUEST_HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'Accept-Encoding': 'gzip, deflate, br',
    'DNT': '1',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
    'Cache-Control': 'max-age=0'
}

SESSION_CONFIG = {
    'timeout': 30,
    'max_redirects': 3,
    'verify': True,  # SSL verification
    'stream': False,  # Download full response
    'allow_redirects': True
}
```

### 5.2 Rate Limiting Strategy

```python
class RateLimiter:
    def __init__(self, min_delay=0.5, max_delay=1.0):
        self.min_delay = min_delay
        self.max_delay = max_delay
        self.current_delay = min_delay
        self.consecutive_429s = 0
    
    def wait(self):
        """Adaptive delay based on response"""
        delay = random.uniform(self.min_delay, self.current_delay)
        time.sleep(delay)
    
    def handle_429(self):
        """Increase delay on rate limit"""
        self.consecutive_429s += 1
        self.current_delay = min(
            self.current_delay * 1.5,
            self.max_delay * 3
        )
    
    def handle_success(self):
        """Gradually reduce delay on success"""
        self.consecutive_429s = 0
        self.current_delay = max(
            self.current_delay * 0.95,
            self.max_delay
        )
```

### 5.3 Response Handling

```python
def process_response(response):
    """Comprehensive response processing"""
    
    # Status code handling
    if response.status_code == 200:
        return process_success(response)
    elif response.status_code == 404:
        raise URLNotFoundError(f"Product not found: {response.url}")
    elif response.status_code == 429:
        retry_after = response.headers.get('Retry-After', 60)
        raise RateLimitError(f"Rate limited. Retry after {retry_after}s")
    elif 500 <= response.status_code < 600:
        raise ServerError(f"Server error {response.status_code}")
    else:
        raise UnexpectedStatusError(f"Unexpected status: {response.status_code}")
    
def process_success(response):
    """Process successful response"""
    
    # Validate content type
    content_type = response.headers.get('Content-Type', '')
    if 'text/html' not in content_type:
        raise InvalidContentError(f"Expected HTML, got {content_type}")
    
    # Validate content length
    content_length = len(response.content)
    if content_length < 10000:  # 10KB minimum
        raise InvalidContentError(f"Response too small: {content_length} bytes")
    if content_length > 10485760:  # 10MB maximum
        raise InvalidContentError(f"Response too large: {content_length} bytes")
    
    return response.content
```

---

## 6. Monitoring and Observability

### 6.1 Logging Configuration

```python
LOGGING_CONFIG = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'detailed': {
            'format': '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            'datefmt': '%Y-%m-%d %H:%M:%S'
        },
        'json': {
            'class': 'pythonjsonlogger.jsonlogger.JsonFormatter',
            'format': '%(asctime)s %(name)s %(levelname)s %(message)s'
        }
    },
    'handlers': {
        'file': {
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': '/app/data/logs/extraction.log',
            'maxBytes': 104857600,  # 100MB
            'backupCount': 5,
            'formatter': 'detailed'
        },
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'detailed',
            'stream': 'ext://sys.stdout'
        }
    },
    'loggers': {
        '': {
            'handlers': ['file', 'console'],
            'level': 'INFO'
        }
    }
}
```

### 6.2 Metrics Collection

```python
class MetricsCollector:
    def __init__(self):
        self.metrics = {
            'urls_processed': 0,
            'urls_succeeded': 0,
            'urls_failed': 0,
            'bytes_downloaded': 0,
            'bytes_saved': 0,
            'processing_times': [],
            'error_counts': defaultdict(int)
        }
    
    def record_success(self, url, download_size, save_size, duration):
        self.metrics['urls_processed'] += 1
        self.metrics['urls_succeeded'] += 1
        self.metrics['bytes_downloaded'] += download_size
        self.metrics['bytes_saved'] += save_size
        self.metrics['processing_times'].append(duration)
    
    def record_failure(self, url, error_type):
        self.metrics['urls_processed'] += 1
        self.metrics['urls_failed'] += 1
        self.metrics['error_counts'][error_type] += 1
    
    def get_summary(self):
        return {
            'total_processed': self.metrics['urls_processed'],
            'success_rate': self.metrics['urls_succeeded'] / max(1, self.metrics['urls_processed']),
            'average_processing_time': np.mean(self.metrics['processing_times']),
            'p95_processing_time': np.percentile(self.metrics['processing_times'], 95),
            'compression_ratio': self.metrics['bytes_saved'] / max(1, self.metrics['bytes_downloaded']),
            'error_breakdown': dict(self.metrics['error_counts'])
        }
```

### 6.3 Health Checks

```python
@app.route('/health')
def health_check():
    """Container health endpoint"""
    checks = {
        'status': 'healthy',
        'container_id': os.environ.get('CONTAINER_ID'),
        'uptime_seconds': time.time() - START_TIME,
        'urls_processed': processor.urls_processed,
        'disk_space_available_gb': shutil.disk_usage('/').free / 1e9,
        'memory_usage_mb': psutil.Process().memory_info().rss / 1e6
    }
    
    # Determine health status
    if checks['disk_space_available_gb'] < 1:
        checks['status'] = 'unhealthy'
        checks['reason'] = 'Low disk space'
    elif checks['memory_usage_mb'] > 1800:
        checks['status'] = 'unhealthy'
        checks['reason'] = 'High memory usage'
    
    return jsonify(checks)
```

---

## 7. Security Considerations

### 7.1 Input Validation

```python
def sanitize_url(url):
    """Validate and sanitize input URLs"""
    
    # URL format validation
    parsed = urlparse(url)
    
    # Must be HTTPS
    if parsed.scheme != 'https':
        raise ValueError(f"Only HTTPS URLs allowed: {url}")
    
    # Must be 1stdibs.com
    if parsed.netloc != 'www.1stdibs.com':
        raise ValueError(f"Only 1stdibs.com URLs allowed: {url}")
    
    # Must contain product ID
    if not re.search(r'/id-f_\d+/', url):
        raise ValueError(f"Invalid product URL format: {url}")
    
    # Prevent path traversal
    if '..' in url or '//' in url[8:]:
        raise ValueError(f"Invalid URL path: {url}")
    
    return url
```

### 7.2 Data Sanitization

```python
def sanitize_extracted_data(data):
    """Sanitize extracted data before saving"""
    
    # Remove any potential XSS vectors
    def clean_string(s):
        if not isinstance(s, str):
            return s
        # Remove script tags
        s = re.sub(r'<script[^>]*>.*?</script>', '', s, flags=re.DOTALL)
        # Remove event handlers
        s = re.sub(r'on\w+="[^"]*"', '', s)
        # Strip remaining HTML
        s = BeautifulSoup(s, 'html.parser').get_text()
        return s.strip()
    
    # Recursively clean all strings
    if isinstance(data, dict):
        return {k: sanitize_extracted_data(v) for k, v in data.items()}
    elif isinstance(data, list):
        return [sanitize_extracted_data(item) for item in data]
    elif isinstance(data, str):
        return clean_string(data)
    else:
        return data
```

### 7.3 Container Security

```dockerfile
# Run as non-root user
RUN addgroup -g 1000 extractor && \
    adduser -D -u 1000 -G extractor extractor

# Set ownership
RUN chown -R extractor:extractor /app

# Switch to non-root user
USER extractor

# Read-only root filesystem
# Mount points for data must be explicitly defined
```

---

## 8. Testing Specifications

### 8.1 Unit Tests

```python
class TestProductExtractor(unittest.TestCase):
    def setUp(self):
        self.extractor = ProductExtractor()
        
    def test_extract_product_id(self):
        """Test product ID extraction from URL"""
        url = "https://www.1stdibs.com/furniture/mirrors/id-f_10001073/"
        product_id = self.extractor.extract_product_id(url)
        self.assertEqual(product_id, "f_10001073")
    
    def test_parse_dimensions(self):
        """Test dimension parsing from description"""
        description = "Height 34 1/2 x width 48 inches"
        dimensions = self.extractor.parse_dimensions(description)
        self.assertEqual(dimensions['height'], "34 1/2 inches")
        self.assertEqual(dimensions['width'], "48 inches")
    
    def test_multi_currency_extraction(self):
        """Test extraction of multiple currencies"""
        offers = [
            {"price": 5400, "priceCurrency": "USD"},
            {"price": 4814.55, "priceCurrency": "EUR"}
        ]
        pricing = self.extractor.extract_pricing(offers)
        self.assertEqual(pricing['price'], "5400")
        self.assertEqual(pricing['multi_currency']['EUR'], 4814.55)
```

### 8.2 Integration Tests

```python
def test_full_extraction_pipeline():
    """Test complete extraction pipeline"""
    
    # Setup
    test_url = "https://www.1stdibs.com/test/id-f_12345/"
    collector = RawHTMLCollector()
    extractor = ProductExtractor()
    
    # Execute
    html_data = collector.fetch_single_html(test_url)
    extracted = extractor.extract(html_data.html_content, test_url)
    
    # Verify
    assert extracted['extraction_status'] == 'success'
    assert extracted['data']['product_info']['product_id'] == 'f_12345'
    assert len(extracted['data']['images']) > 0
    assert 'USD' in extracted['data']['pricing']['multi_currency']
```

### 8.3 Performance Tests

```python
def benchmark_extraction_speed():
    """Benchmark extraction performance"""
    
    html_samples = load_test_samples()  # 100 HTML files
    extractor = ProductExtractor()
    
    start_time = time.time()
    for html in html_samples:
        extractor.extract(html, "test_url")
    
    elapsed = time.time() - start_time
    avg_time = elapsed / len(html_samples)
    
    assert avg_time < 0.5  # Must process in under 500ms
    print(f"Average extraction time: {avg_time*1000:.2f}ms")
```

---

## 9. Operational Procedures

### 9.1 Deployment Checklist

```markdown
- [ ] Validate all URLs in input file
- [ ] Ensure sufficient disk space (200MB per 1000 URLs)
- [ ] Build and test Docker image locally
- [ ] Run security scan on Docker image
- [ ] Configure environment variables
- [ ] Set up monitoring dashboards
- [ ] Configure log aggregation
- [ ] Test rollback procedure
- [ ] Document chunk assignments
- [ ] Verify network connectivity
```

### 9.2 Maintenance Procedures

#### Daily Tasks
```bash
# Check container health
for container in $(docker ps --format "{{.Names}}" | grep 1stdibs); do
  echo "Checking $container..."
  docker exec $container curl -s localhost:8080/health | jq .
done

# Review error rates
for log in data/*/logs/extraction.log; do
  echo "Errors in $log:"
  grep ERROR $log | tail -10
done
```

#### Weekly Tasks
```bash
# Archive completed data
for dir in data/*/; do
  if [ -f "$dir/container_*_summary.json" ]; then
    tar -czf "archive/$(basename $dir)_$(date +%Y%m%d).tar.gz" $dir
  fi
done

# Clean old logs
find data/*/logs -name "*.log.*" -mtime +7 -delete
```

### 9.3 Disaster Recovery

#### Backup Procedures
```bash
# Backup to S3
aws s3 sync data/ s3://backup-bucket/1stdibs-data/ \
  --exclude "*/logs/*" \
  --storage-class GLACIER

# Verify backup integrity
aws s3 ls s3://backup-bucket/1stdibs-data/ --recursive | wc -l
```

#### Recovery Procedures
```bash
# Restore from checkpoint
docker run -d \
  --name extractor-phoenix-recovery \
  -e RESUME_FROM_CHECKPOINT=true \
  -v $(pwd)/data/phoenix:/app/data \
  1stdibs-extractor:phoenix

# Reprocess failed URLs
grep "Failed" data/phoenix/logs/extraction.log | \
  grep -oE 'https://[^ ]+' > phoenix_retry.txt
```

---

This comprehensive technical specification provides granular details about every aspect of the 1stDibs extraction pipeline, from data structures to deployment procedures. The system is designed for reliability, scalability, and maintainability at production scale.