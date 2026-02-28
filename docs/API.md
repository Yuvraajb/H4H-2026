# GuideVR API Documentation

Complete API documentation for GuideVR backend services.

## Base URL

- Development: `http://localhost:8000`
- WebSocket: `ws://localhost:8000`

## WebSocket API

### Endpoint: `/ws/session`

Real-time bidirectional communication for session management.

#### Client → Server Messages

##### Start Session
```json
{
  "type": "start_session",
  "mode": "live" | "training",
  "scenario": "string" // optional, for training mode
}
```

##### Send Utterance
```json
{
  "type": "utterance",
  "text": "user's spoken words",
  "timestamp": "2024-01-01T12:00:00.000Z"
}
```

##### End Session
```json
{
  "type": "end_session"
}
```

#### Server → Client Messages

##### Session Started
```json
{
  "type": "session_started",
  "session_id": "uuid-string"
}
```

##### AI Response
```json
{
  "type": "response",
  "text": "AI spoken text",
  "metadata": {
    "step": 1,
    "urgency": "low" | "medium" | "high" | "critical",
    "image_query": "string" | null,
    "category": "string",
    "display_text": "string"
  }
}
```

##### Training Complete
```json
{
  "type": "training_complete",
  "score": {
    "overall": 85,
    "correct_actions": ["action1", "action2"],
    "missed_actions": ["action3"],
    "feedback": "string"
  }
}
```

##### Session Ended
```json
{
  "type": "session_ended",
  "session_id": "uuid-string"
}
```

##### Error
```json
{
  "type": "error",
  "message": "error description"
}
```

## REST API

### Images

#### GET `/api/images`

Retrieve an instructional image for a query.

**Query Parameters:**
- `q` (required): Search query string

**Response:**
```json
{
  "image_url": "https://example.com/image.jpg",
  "caption": "Instructional image caption",
  "source": "Google Custom Search"
}
```

**Example:**
```bash
curl "http://localhost:8000/api/images?q=CPR%20technique"
```

### Sessions

#### GET `/api/session/{session_id}`

Get session details by ID.

**Path Parameters:**
- `session_id` (required): Session UUID

**Response:**
```json
{
  "id": "uuid-string",
  "mode": "live" | "training",
  "start_time": "2024-01-01T12:00:00.000Z",
  "end_time": "2024-01-01T12:05:00.000Z",
  "transcript": [
    {
      "id": "entry-id",
      "speaker": "user" | "ai",
      "text": "transcript text",
      "timestamp": "2024-01-01T12:00:00.000Z"
    }
  ],
  "metadata": [
    {
      "step": 1,
      "urgency": "medium",
      "image_query": "string",
      "category": "string",
      "display_text": "string"
    }
  ]
}
```

#### POST `/api/session/{session_id}/end`

End a session and return summary.

**Path Parameters:**
- `session_id` (required): Session UUID

**Response:**
```json
{
  "session_id": "uuid-string",
  "duration": 300,
  "summary": "Session completed with 10 transcript entries."
}
```

### Reports

#### POST `/api/report/{session_id}/generate`

Generate a PDF report for a session.

**Path Parameters:**
- `session_id` (required): Session UUID

**Response:**
- Content-Type: `application/pdf`
- Body: PDF file bytes

**Example:**
```bash
curl -X POST "http://localhost:8000/api/report/{session_id}/generate" \
  --output report.pdf
```

## Health Check

#### GET `/health`

Check backend health status.

**Response:**
```json
{
  "status": "healthy"
}
```

## Error Responses

All endpoints may return error responses in the following format:

```json
{
  "error": "Error message description"
}
```

HTTP Status Codes:
- `400`: Bad Request
- `404`: Not Found
- `500`: Internal Server Error

## Rate Limiting

Currently no rate limiting is implemented. This may be added in the future.

## Authentication

Currently no authentication is required. This may be added for production deployments.
