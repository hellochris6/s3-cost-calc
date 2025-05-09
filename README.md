# S3 Glacier Restore Cost Calculator

This interactive shell script estimates the cost of restoring objects from AWS S3 Glacier, based on object sizes and user-defined restore preferences. It also optionally logs restore requests to Airtable for finance tracking and audit purposes.

## Features

- Supports bulk input of object sizes in GiB
- Calculates total cost using AWS Glacier pricing:
  - **$0.02 per GiB retrieved**
  - **$0.10 per 1,000 objects retrieved**
- Converts size to both GiB and GB for clarity
- Supports **Standard** and **Bulk** retrieval options
- Prompts for retention period (default: 1 day)
- Logs cost details to Airtable via webhook (optional)

## Requirements

- Unix-like shell (macOS, Linux, WSL)
- `bash`
- `bc` (basic calculator utility)
- `curl` (for Airtable integration)

## Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/s3-cost-calc.git
   cd s3-cost-calc
