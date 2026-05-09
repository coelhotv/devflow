---
id: CON-XXX
title: [Service/API contract name]
version: "1.0"
status: draft | active | deprecated
tags:
  - [service-name]
  - [tag1]
interface_type: [service | hook | api-endpoint | schema | component]
last_updated: [YYYY-MM-DD]
---

# CON-XXX: [Contract Name]

**Version:** 1.0
**Status:** active
**Interface Type:** service | hook | api-endpoint | schema | component
**Last Updated:** YYYY-MM-DD

## Overview

Describe what this service/hook/component does in 1-2 sentences.

## Function Signature

```javascript
export function serviceName(param1: Type1, param2: Type2): ReturnType {
  // implementation
}
```

Or for React hooks:
```javascript
export function useMyHook(deps: DependencyType): ReturnType {
  // implementation
}
```

## Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| param1 | Type | Yes | What this param does |
| param2 | Type | No | Optional param description |

## Returns

Describe what the function returns:
- Type
- Shape (if object)
- Possible values
- Error behavior

## Usage Example

```javascript
// Real usage example
const result = serviceName(arg1, arg2)
// Expected output
```

## Implementation Details

### Internal Behavior
- How does it work?
- What are the key steps?
- Any important assumptions?

### Dependencies
- What other services does it use?
- External APIs?
- Database queries?

## Error Handling

Describe error cases:
- What can go wrong?
- How are errors handled?
- What should callers do?

```javascript
// Error handling example
try {
  const result = serviceName(arg)
} catch (error) {
  // Expected error type and recovery
}
```

## Testing

### Test Cases
- Happy path
- Edge cases
- Error cases

### Example Tests
```javascript
test('should handle case X', () => {
  // test example
})
```

## Related Contracts

- Links to dependent services
- Links to schemas this uses
- Links to components that consume this

## Changelog

- **v1.0** (YYYY-MM-DD): Initial version
