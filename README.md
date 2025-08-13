# Panda CI

Pre-built Docker images for Panda project CI/CD pipelines. These images include all common dependencies needed for testing Panda CMS, Panda Core, and Panda Editor, significantly reducing CI setup time.

## 📦 Docker Images

Images are available at: `ghcr.io/tastybamboo/panda-ci`

To view available images:
```bash
# View all available tags
gh api /orgs/tastybamboo/packages/container/panda-ci/versions --jq '.[].metadata.container.tags[]' | sort -u
```

## 🚀 Quick Start

Replace your GitHub Actions job configuration:

### Before (slow - installs dependencies every run):
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install system dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y libvips42 imagemagick chromium-browser
          # ... more installation steps

      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.3
          bundler-cache: true
```

### After (fast - pre-installed dependencies):
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tastybamboo/panda-ci:ruby-3.4.5
    steps:
      - uses: actions/checkout@v4

      - name: Bundle install
        run: bundle install --jobs 4 --retry 3
```

## 📦 What's Included

- **Ruby versions**: 3.2.6, 3.3.7, 3.4.5 (latest)
- **System packages**:
  - PostgreSQL client
  - ImageMagick & libvips (image processing)
  - Chromium & ChromeDriver (system tests)
  - Xvfb (headless browser testing)
  - Build essentials
- **Pre-installed gems**:
  - bundler 2.7.1
  - Common testing/linting gems (rspec, standard, rubocop, etc.)
- **Configuration**:
  - UTC timezone
  - en_US.UTF-8 locale
  - Chromium configured for headless operation

## 🏷️ Available Tags

### Latest (Recommended)
- `ghcr.io/tastybamboo/panda-ci:latest` - Ruby 3.4.5 (amd64 + arm64)

### By Ruby Version
- `ghcr.io/tastybamboo/panda-ci:ruby-3.4.5` - Ruby 3.4.5
- `ghcr.io/tastybamboo/panda-ci:ruby-3.3.7` - Ruby 3.3.7
- `ghcr.io/tastybamboo/panda-ci:ruby-3.2.6` - Ruby 3.2.6

### Architecture Support
- **Daily/Push builds**: `linux/amd64` only (optimized for CI speed)
- **Weekly/Manual builds**: `linux/amd64` + `linux/arm64` (for local development on Apple Silicon)

### Date-Tagged Versions
For reproducible builds:
- `ghcr.io/tastybamboo/panda-ci:ruby-3.4.5-20250813`
- `ghcr.io/tastybamboo/panda-ci:ruby-3.3.7-20250813`
- `ghcr.io/tastybamboo/panda-ci:ruby-3.2.6-20250813`

## 💻 Usage Examples

### Basic Test Job
```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tastybamboo/panda-ci:ruby-3.4.5

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: password
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - name: Setup database
        run: |
          bundle install
          bundle exec rails db:create db:schema:load
        env:
          DATABASE_URL: postgresql://postgres:password@postgres/test

      - name: Run tests
        run: bundle exec rspec
```

### Matrix Testing with Multiple Ruby Versions
```yaml
jobs:
  test:
    strategy:
      matrix:
        ruby-version: ['3.2.6', '3.3.7', '3.4.5']

    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tastybamboo/panda-ci:ruby-${{ matrix.ruby-version }}

    steps:
      - uses: actions/checkout@v4
      - run: bundle install
      - run: bundle exec rspec
```

### With Caching
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tastybamboo/panda-ci:ruby-3.4.5

    steps:
      - uses: actions/checkout@v4

      - name: Cache gems
        uses: actions/cache@v3
        with:
          path: vendor/bundle
          key: ${{ runner.os }}-gems-${{ hashFiles('**/Gemfile.lock') }}
          restore-keys: |
            ${{ runner.os }}-gems-

      - name: Bundle install
        run: |
          bundle config path vendor/bundle
          bundle install --jobs 4 --retry 3

      - name: Run tests
        run: bundle exec rspec
```

## 🔧 Local Development

You can use these images locally for consistent development environments:

```bash
# Pull the image
docker pull ghcr.io/tastybamboo/panda-ci:ruby-3.4.5

# Run tests in a container
docker run --rm -v $(pwd):/app ghcr.io/tastybamboo/panda-ci:ruby-3.4.5 \
  bash -c "bundle install && bundle exec rspec"

# Interactive development
docker run -it --rm -v $(pwd):/app ghcr.io/tastybamboo/panda-ci:ruby-3.4.5 bash
```

## 🔄 Automatic Updates

The images are automatically rebuilt:

- When the Dockerfile changes
- Weekly (Sunday at midnight UTC) for security updates
- On-demand via workflow dispatch

## 🛠️ Building Custom Images

If you need to customize the image:

1. Fork this repository
2. Modify the `Dockerfile`
3. Update the `IMAGE_NAME` in `.github/workflows/build-and-publish.yml`
4. Push to your fork's main branch

The GitHub Actions workflow will automatically build and publish to your GitHub Container Registry.

## 📈 Performance Improvements

Typical time savings per CI run:

- **Before**: ~45-60 seconds for dependency installation
- **After**: ~5-10 seconds for container pull (cached after first run)
- **Net savings**: 35-50 seconds per job

For a matrix with 9 jobs (3 Ruby × 3 Rails versions):
- **Total savings**: ~5-7 minutes per CI run

## 🐛 Troubleshooting

### Container fails to start
Ensure you're using `actions/checkout@v4` which is compatible with containerized jobs.

### Permission issues
The container runs as root by default. If you need a non-root user, the `panda` user is available:
```yaml
container:
  image: ghcr.io/tastybamboo/panda-ci:ruby-3.3
  options: --user panda
```

### Can't access PostgreSQL service
Use the service name as the hostname:
```yaml
DATABASE_URL: postgresql://postgres:password@postgres/test
```

### Image not found
The images are public, but ensure you're using the correct registry URL: `ghcr.io/tastybamboo/panda-ci`

## 📝 License

Copyright 2024-2025 Otaina Limited. Available under the BSD 3-Clause License.

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📞 Support

For issues or questions, please [open an issue](https://github.com/tastybamboo/panda-ci/issues).
