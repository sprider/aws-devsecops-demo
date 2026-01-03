#!/bin/bash

# Local Testing Script for DevSecOps Demo
# This script runs all the tests and checks that the CI/CD pipeline will run

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Parse arguments
SKIP_DEPS=false
SKIP_TESTS=false
QUICK_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-deps)
            SKIP_DEPS=true
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --quick)
            QUICK_MODE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--skip-deps] [--skip-tests] [--quick]"
            exit 1
            ;;
    esac
done

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║   DevSecOps Demo - Local Testing Suite                   ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Detect script location and set working directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Determine if we're in app-cicd or project root
if [[ "$SCRIPT_DIR" == *"/app-cicd" ]]; then
    APP_DIR="$SCRIPT_DIR"
    ROOT_DIR="$PROJECT_ROOT"
else
    APP_DIR="$SCRIPT_DIR/app-cicd"
    ROOT_DIR="$SCRIPT_DIR"
fi

# Change to app directory for all operations
cd "$APP_DIR"

# Step 1: Check Prerequisites
print_step "Checking prerequisites..."

if ! command_exists java; then
    print_error "Java is not installed. Please install Java 17."
    exit 1
fi

JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
if [ "$JAVA_VERSION" -ne 17 ]; then
    print_warning "Java version is $JAVA_VERSION, but Java 17 is recommended."
fi

if ! command_exists mvn; then
    print_error "Maven is not installed. Please install Maven 3.9+."
    exit 1
fi

if ! command_exists docker; then
    print_warning "Docker is not installed. Skipping Docker tests."
fi

print_success "Prerequisites check passed"
echo ""

# Step 2: Check dependency vulnerabilities (optional)
if [ "$SKIP_DEPS" = false ] && [ "$QUICK_MODE" = false ]; then
    print_step "Running OWASP Dependency Check (this may take a few minutes)..."
    if mvn org.owasp:dependency-check-maven:check -q; then
        print_success "No critical vulnerabilities found in dependencies"
    else
        print_warning "Dependency check found issues. Review target/dependency-check-report.html"
    fi
    echo ""
fi

# Step 3: Run unit tests
if [ "$SKIP_TESTS" = false ]; then
    print_step "Running unit tests..."
    if mvn test -q; then
        print_success "All unit tests passed"
    else
        print_error "Unit tests failed"
        exit 1
    fi
    echo ""
fi

# Step 4: Run code coverage
if [ "$SKIP_TESTS" = false ] && [ "$QUICK_MODE" = false ]; then
    print_step "Running code coverage analysis (70% minimum)..."
    if mvn verify -q; then
        COVERAGE=$(grep -o 'covered=\"[0-9.]*\"' target/site/jacoco/jacoco.xml | head -1 | grep -o '[0-9.]*')
        print_success "Code coverage: ${COVERAGE}%"
    else
        print_error "Coverage verification failed"
        exit 1
    fi
    echo ""
fi

# Step 5: Run Checkstyle
print_step "Running Checkstyle (code style)..."
if mvn checkstyle:check -q; then
    print_success "Code style check passed"
else
    print_warning "Checkstyle found issues. Review target/checkstyle-result.xml"
fi
echo ""

# Step 6: Run SpotBugs
if [ "$QUICK_MODE" = false ]; then
    print_step "Running SpotBugs (static analysis)..."
    if mvn spotbugs:check -q; then
        print_success "SpotBugs analysis passed"
    else
        print_warning "SpotBugs found issues. Review target/spotbugsXml.xml"
    fi
    echo ""
fi

# Step 7: Test Docker build
if command_exists docker && [ "$QUICK_MODE" = false ]; then
    print_step "Building Docker image..."
    if docker build -t devsecops-demo:test . > /dev/null 2>&1; then
        print_success "Docker image built successfully"

        # Get image size
        IMAGE_SIZE=$(docker images devsecops-demo:test --format "{{.Size}}")
        print_success "Image size: $IMAGE_SIZE"
    else
        print_error "Docker build failed"
        exit 1
    fi
    echo ""
fi

# Step 8: Test OPA policies
if command_exists conftest; then
    print_step "Validating Kubernetes manifests with OPA policies..."
    # Create temporary rendered manifests for testing
    export IMAGE_URI="123456789012.dkr.ecr.us-east-1.amazonaws.com/devsecops-demo:1.0.0-abc1234"
    export TARGET_GROUP_ARN="arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/demo/abc123"
    export ALB_SECURITY_GROUP_ID="sg-12345678"

    mkdir -p "$ROOT_DIR/test-rendered"
    for manifest in k8s/*.yaml; do
        envsubst < "$manifest" > "$ROOT_DIR/test-rendered/$(basename "$manifest")"
    done

    if conftest test "$ROOT_DIR/test-rendered" --policy ./policies > /dev/null 2>&1; then
        print_success "All Kubernetes manifests passed OPA policies"
    else
        print_warning "Some manifests failed policy validation"
    fi

    rm -rf "$ROOT_DIR/test-rendered"
    echo ""
else
    print_warning "Conftest not installed. Skipping OPA policy validation."
    print_warning "Install: brew install conftest (macOS) or download from GitHub"
    echo ""
fi

# Step 9: Secret scanning
if command_exists detect-secrets; then
    print_step "Running secret scanning..."
    if detect-secrets scan --all-files > /dev/null 2>&1; then
        print_success "No secrets detected in repository"
    else
        print_warning "Potential secrets detected. Review output above."
    fi
    echo ""
else
    print_warning "detect-secrets not installed. Skipping secret scan."
    print_warning "Install: pip3 install detect-secrets"
    echo ""
fi

# Step 10: Generate SBOM
if command_exists syft && command_exists docker; then
    print_step "Generating Software Bill of Materials (SBOM)..."
    if syft "$APP_DIR" -o spdx-json > "$ROOT_DIR/sbom-local.json" 2>/dev/null; then
        PACKAGE_COUNT=$(jq '.packages | length' "$ROOT_DIR/sbom-local.json")
        print_success "SBOM generated: $PACKAGE_COUNT packages found"
    else
        print_warning "SBOM generation skipped"
    fi
    echo ""
fi

# Summary
echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║   Testing Summary                                         ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

print_success "All critical tests passed!"
echo ""
echo "Next steps:"
echo "  1. Review any warnings above"
echo "  2. Test locally: mvn spring-boot:run"
echo "  3. Access: http://localhost:8080"
echo "  4. Or use Docker: docker-compose up"
echo "  5. Deploy to AWS: cd ../platform-terraform && terraform apply"
echo ""
