# API Connection Issue - Deep Research Findings

## Executive Summary

**Problem**: Flutter app shows "Failed to load routes" with SSL errors, but Postman works fine.

**Root Cause**: Backend PostgreSQL database connection pool has stale SSL connections that aren't being recycled properly.

**Status**: ✅ IDENTIFIED AND FIXED (with client-side retry + backend recommendations)

---

## Detailed Analysis

### What We Discovered

Running comprehensive diagnostic tests revealed:

1. **First Request (Test 1)**: ✅ **SUCCESS** - 200 OK, returned 10 routes (2407ms)
2. **Second Request (Test 2)**: ❌ **FAILED** - 500 SSL error (immediately after Test 1)
3. **Third Test (rapid 3 requests)**: ✅ **ALL SUCCEEDED** - 200 OK for all 3

### Key Finding

The error is **INTERMITTENT**, not consistent:

- Sometimes requests succeed (200 OK with data)
- Sometimes the same request fails (500 SSL error)
- The issue happens at the **backend database layer**, not the HTTP layer

### Error Message Breakdown

```
(psycopg2.OperationalError) SSL error: decryption failed or bad record mac
[SQL: SELECT "Route".id AS "Route_id", ...]
```

**What this means**:

1. The Flask backend receives the HTTP request successfully ✅
2. The backend tries to query PostgreSQL ✅
3. The PostgreSQL SSL connection fails ❌
4. Backend returns 500 error to client

---

## Why Postman Works But Flutter Fails

### Postman Behavior

- Requests are typically spaced apart (manual clicking)
- Gives backend time to recycle connections
- May reuse warm HTTP connections
- You likely tested when database pool was fresh

### Flutter App Behavior

- Makes requests automatically on page load
- May hit the backend when pool has stale connections
- Gets unlucky timing-wise
- No built-in retry mechanism

### SSL Certificate Status

✅ Certificate is VALID:

- Subject: onrender.com
- Issuer: Google Trust Services (WE1)
- Valid until: Dec 31, 2025
- SSL handshake to backend: **SUCCESSFUL**

The SSL issue is NOT with HTTPS to the backend - it's with the backend's connection to PostgreSQL.

---

## The Real Problem: Database Connection Pooling

### What's Happening

1. Backend creates a pool of database connections
2. Connections are reused for performance
3. Some connections develop SSL handshake issues over time
4. Backend doesn't detect bad connections before using them
5. When a bad connection is used → SQL query fails → 500 error

### Why SSL Connections Go Bad

- Network interruptions
- PostgreSQL server timeout/restart
- SSL session renegotiation failures
- Render platform connection recycling
- Long idle times causing SSL state corruption

---

## Solutions Implemented

### Client-Side Fix (Flutter App) ✅

Added **automatic retry with exponential backoff**:

```dart
// Retry up to 3 times
// Delays: 1s, 2s, 4s (exponential backoff)
// Only retries on database SSL errors (500 with psycopg2.OperationalError)
```

**Benefits**:

- App now handles transient database issues gracefully
- Users see success on retry instead of error dialog
- Works around backend issue until properly fixed

### Backend Fix Required (Recommended)

Add to your SQLAlchemy engine configuration:

```python
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,      # ⭐ Test connections before using
    pool_recycle=300,        # ⭐ Recycle every 5 minutes
    pool_size=5,
    max_overflow=10,
    connect_args={
        "sslmode": "require",
        "connect_timeout": 10,
    }
)
```

**What these do**:

- `pool_pre_ping=True`: Sends "SELECT 1" to test connection health before using it
- `pool_recycle=300`: Forces new connection every 5 minutes (prevents stale SSL)

**Alternative (simpler but slower)**:

```python
from sqlalchemy.pool import NullPool

engine = create_engine(
    DATABASE_URL,
    poolclass=NullPool,  # No pooling - new connection every time
    connect_args={"sslmode": "require"}
)
```

---

## Test Results

### Diagnostic Test Output

```
TEST 1: dart:io HttpClient
✅ SUCCESS! Status: 200 OK
   Routes count: 10
   Response time: 2407ms

TEST 2: With extended timeouts
❌ FAILED! Status: 500
   Error: psycopg2.OperationalError SSL error

TEST 3: Connection pooling (3 rapid requests)
✅ Request #1: SUCCESS (200)
✅ Request #2: SUCCESS (200)
✅ Request #3: SUCCESS (200)

TEST 4: SSL Certificate
✅ Certificate is VALID
   Subject: onrender.com
   Valid until: 2025-12-31
```

---

## Conclusion

### What We Learned

1. **HTTP layer works perfectly** - SSL handshake to backend is fine
2. **Database layer has issues** - PostgreSQL connection pool needs configuration
3. **Problem is intermittent** - depends on state of connection pool
4. **Client retry solves it** - 3 retries handles most failures
5. **Backend fix prevents it** - Proper pool configuration eliminates root cause

### Current Status

✅ **Flutter app fixed** with retry logic  
⏳ **Backend needs update** for permanent fix  
✅ **Issue understood** and documented

### Next Steps

1. **Short term**: Use Flutter app with retry logic (DONE)
2. **Long term**: Update backend with `pool_pre_ping` and `pool_recycle` (RECOMMENDED)
3. **Monitoring**: Track retry counts to see how often backend fails

---

## Files Modified

1. `lib/services/routes_api.dart` - Added retry logic with exponential backoff
2. `deep_api_test.dart` - Created comprehensive diagnostic test
3. `test_api.dart` - Simple API verification test

## Additional Resources

- SQLAlchemy pooling: https://docs.sqlalchemy.org/en/20/core/pooling.html
- Render PostgreSQL SSL: https://render.com/docs/databases#ssl-connections
- psycopg2 SSL errors: https://www.psycopg.org/docs/module.html#psycopg2.OperationalError

---

**Last Updated**: October 6, 2025  
**Status**: RESOLVED (with retry) / BACKEND UPDATE PENDING
