# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Social Construct is a Rails engine for generating social media preview cards (Open Graph images) with built-in preview functionality. It uses headless Chrome via Ferrum to render HTML templates as PNG images.

The base directory hosts the gem code. For an example Rails app, see test/dummy/.
`bin/rails` commands will work on this dummy.

## Common Development Commands

### Testing

```bash
# Run all tests
bin/rails test

# Run specific test file
bin/rails test test/social_construct_test.rb

# Run specific test method
bin/rails test test/social_construct_test.rb -n test_method_name

# Run controller tests only
bin/rails test test/controllers

# Run model tests only
bin/rails test test/models
```

### Code Quality

```bash
# Format code with rubyfmt
rubyfmt -i **/*.rb
```

### Development Server

```bash
# Start development server (from test/dummy)
cd test/dummy && bin/rails server

# Access preview interface at
# http://localhost:3000/rails/social_cards
```

### Gem Building

```bash
# Build gem
rake build

# Install locally
rake install

# Release to RubyGems (requires permissions)
rake release
```

### CI/CD

The project uses GitHub Actions for CI testing on Ubuntu with Chrome installed. Ruby version is set to 3.4.4.

## Architecture Overview

### Core Components

1. **BaseCard (`app/models/social_construct/base_card.rb`)**

   - Core abstraction for card generation
   - Renders HTML templates to 1200x630px PNG images
   - Uses Ferrum (headless Chrome) for screenshots
   - Supports debug mode and Docker environments

2. **Controller Concern (`app/controllers/concerns/social_construct/controller.rb`)**

   - Provides `send_social_card` method for controllers
   - Handles caching with configurable TTL
   - Supports both PNG and HTML output formats

3. **Preview System (`app/controllers/social_construct/previews_controller.rb`)**
   - Development-only interface at `/rails/social_cards`
   - Auto-discovers preview classes in `app/social_cards/previews/*_preview.rb`
   - Dual format support for debugging

### Key Patterns

- **Template Resolution**: Card class name → underscored → template path
- **Caching**: Built-in Rails.cache integration with binary PNG storage
- **Image Handling**: Converts Active Storage attachments to data URLs
- **Error Handling**: Falls back to transparent PNG on errors
- **Preview Discovery**: Auto-loads `*_preview.rb` files from `app/social_cards/previews/`

### Directory Structure

```
app/
├── controllers/concerns/social_construct/  # Controller integration
├── controllers/social_construct/          # Preview UI
├── models/social_construct/              # BaseCard class
└── views/social_construct/               # Preview templates

lib/
├── generators/                           # Installation generator
└── social_construct/                     # Engine configuration

test/
└── dummy/                               # Test Rails application
```

### Development Workflow

1. Create card classes inheriting from `BaseCard` or `ApplicationSocialCard`
2. Add corresponding templates in configured template path
3. Create preview classes for development testing
4. Use `send_social_card` in controllers with appropriate cache keys
5. Test using preview interface or integration tests

### Important Notes

- Always use data URLs for embedded images in templates
- Keep templates self-contained with inline styles
- Use debug mode (`debug: true`) when troubleshooting rendering issues
- Remember that Ferrum requires Chrome/Chromium to be installed
- In production, use Docker-compatible browser options for sandboxing
- Large assets (>2MB) will fail data URL conversion with Marcel::MimeType::InvalidMagic error
- Preview classes require public methods that return card instances

## Dependencies

- Rails >= 7.0
- Ferrum >= 0.13 (headless Chrome driver)
- Marcel >= 1.0 (MIME type detection)
- Ruby 3.4.4 (per CI configuration)
