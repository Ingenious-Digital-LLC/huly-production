#!/bin/bash

# Huly Security Verification Script
# This script verifies that all security hardening measures are properly implemented

echo "🔒 Huly Security Verification Report"
echo "Generated: $(date)"
echo "=============================================="

SECURITY_SCORE=0
MAX_SCORE=60

echo
echo "1. CREDENTIAL SECURITY CHECKS"
echo "------------------------------"

# Check for hardcoded MinIO credentials
if grep -q "minioadmin" compose.yml 2>/dev/null; then
    echo "❌ [CRITICAL] Hardcoded MinIO credentials found"
else
    echo "✅ [PASS] No hardcoded MinIO credentials"
    SECURITY_SCORE=$((SECURITY_SCORE + 15))
fi

# Check for unauthenticated MongoDB connections
if grep "mongodb://mongodb:27017" compose.yml 2>/dev/null | grep -qv "authSource=admin"; then
    echo "❌ [CRITICAL] Unauthenticated MongoDB connections found"
else
    echo "✅ [PASS] All MongoDB connections authenticated"
    SECURITY_SCORE=$((SECURITY_SCORE + 15))
fi

# Check for secure application secrets
if [ -f ".huly.secret" ] && [ $(wc -c < .huly.secret) -gt 32 ]; then
    echo "✅ [PASS] Secure application secret configured"
    SECURITY_SCORE=$((SECURITY_SCORE + 10))
else
    echo "❌ [FAIL] Weak or missing application secret"
fi

echo
echo "2. FILE PERMISSION CHECKS"
echo "-------------------------"

# Check .huly.secret permissions
if [ -f ".huly.secret" ] && [ "$(stat -c %a .huly.secret)" = "600" ]; then
    echo "✅ [PASS] .huly.secret has secure permissions (600)"
    SECURITY_SCORE=$((SECURITY_SCORE + 5))
else
    echo "❌ [FAIL] .huly.secret permissions are insecure"
fi

# Check huly.conf permissions
if [ -f "huly.conf" ] && [ "$(stat -c %a huly.conf)" = "600" ]; then
    echo "✅ [PASS] huly.conf has secure permissions (600)"
    SECURITY_SCORE=$((SECURITY_SCORE + 5))
else
    echo "❌ [FAIL] huly.conf permissions are insecure"
fi

echo
echo "3. INFRASTRUCTURE SECURITY"
echo "--------------------------"

# Check for resource limits
RESOURCE_COUNT=$(grep -c "resources:" compose.yml 2>/dev/null || echo 0)
if [ "$RESOURCE_COUNT" -ge 8 ]; then
    echo "✅ [PASS] Resource limits configured ($RESOURCE_COUNT services)"
    SECURITY_SCORE=$((SECURITY_SCORE + 5))
else
    echo "❌ [FAIL] Insufficient resource limits ($RESOURCE_COUNT services)"
fi

# Check for health checks
HEALTH_COUNT=$(grep -c "healthcheck:" compose.yml 2>/dev/null || echo 0)
if [ "$HEALTH_COUNT" -ge 8 ]; then
    echo "✅ [PASS] Health checks configured ($HEALTH_COUNT services)"
    SECURITY_SCORE=$((SECURITY_SCORE + 5))
else
    echo "❌ [FAIL] Insufficient health checks ($HEALTH_COUNT services)"
fi

echo
echo "4. SECURITY SCORE"
echo "----------------"
PERCENTAGE=$((SECURITY_SCORE * 100 / MAX_SCORE))

if [ $PERCENTAGE -ge 90 ]; then
    echo "🟢 SECURITY SCORE: $SECURITY_SCORE/$MAX_SCORE ($PERCENTAGE%) - EXCELLENT"
elif [ $PERCENTAGE -ge 75 ]; then
    echo "🟡 SECURITY SCORE: $SECURITY_SCORE/$MAX_SCORE ($PERCENTAGE%) - GOOD"
elif [ $PERCENTAGE -ge 50 ]; then
    echo "🟠 SECURITY SCORE: $SECURITY_SCORE/$MAX_SCORE ($PERCENTAGE%) - NEEDS IMPROVEMENT"
else
    echo "🔴 SECURITY SCORE: $SECURITY_SCORE/$MAX_SCORE ($PERCENTAGE%) - CRITICAL ISSUES"
fi

echo
echo "5. RECOMMENDATIONS"
echo "-----------------"
if [ $PERCENTAGE -lt 100 ]; then
    echo "• Review failed checks above"
    echo "• Regenerate credentials if any hardcoded values found"
    echo "• Fix file permissions with: chmod 600 .huly.secret huly.conf"
    echo "• Add missing resource limits and health checks"
else
    echo "• Security configuration is optimal"
    echo "• Schedule quarterly security reviews"
    echo "• Monitor logs for unauthorized access attempts"
fi

echo
echo "=============================================="
echo "Security verification complete."

# Exit with non-zero code if security score is below 90%
if [ $PERCENTAGE -lt 90 ]; then
    exit 1
else
    exit 0
fi