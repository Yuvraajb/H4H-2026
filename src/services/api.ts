import { ClientMessage, ServerMessage, ImageResult } from '../types';

const BACKEND_URL = import.meta.env.VITE_BACKEND_URL || 'ws://localhost:8000';

let ws: WebSocket | null = null;
let messageHandlers: ((message: ServerMessage) => void)[] = [];

export const connectWebSocket = (onMessage: (message: ServerMessage) => void): Promise<void> => {
  return new Promise((resolve, reject) => {
    try {
      ws = new WebSocket(`${BACKEND_URL}/ws/session`);
      
      ws.onopen = () => {
        console.log('WebSocket connected');
        resolve();
      };
      
      ws.onmessage = (event) => {
        try {
          const message: ServerMessage = JSON.parse(event.data);
          onMessage(message);
          messageHandlers.forEach(handler => handler(message));
        } catch (error) {
          console.error('Error parsing WebSocket message:', error);
        }
      };
      
      ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        reject(error);
      };
      
      ws.onclose = () => {
        console.log('WebSocket disconnected');
        ws = null;
      };
    } catch (error) {
      console.error('Error connecting WebSocket:', error);
      reject(error);
    }
  });
};

export const sendWebSocketMessage = (message: ClientMessage): void => {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(message));
    console.log('Sent WebSocket message:', message);
  } else {
    console.warn('WebSocket not connected, message not sent:', message);
  }
};

export const disconnectWebSocket = (): void => {
  if (ws) {
    ws.close();
    ws = null;
  }
};

export const fetchImage = async (query: string): Promise<ImageResult> => {
  try {
    const response = await fetch(`${BACKEND_URL.replace('ws://', 'http://').replace('wss://', 'https://')}/api/images?q=${encodeURIComponent(query)}`);
    if (!response.ok) {
      throw new Error('Failed to fetch image');
    }
    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Error fetching image:', error);
    // Return mock data
    return {
      image_url: 'https://via.placeholder.com/400x300?text=Instructional+Image',
      caption: `Mock image for: ${query}`,
      source: 'Mock',
    };
  }
};

export const fetchSession = async (sessionId: string): Promise<any> => {
  try {
    const response = await fetch(`${BACKEND_URL.replace('ws://', 'http://').replace('wss://', 'https://')}/api/session/${sessionId}`);
    if (!response.ok) {
      throw new Error('Failed to fetch session');
    }
    return await response.json();
  } catch (error) {
    console.error('Error fetching session:', error);
    return null;
  }
};

export const endSession = async (sessionId: string): Promise<any> => {
  try {
    const response = await fetch(`${BACKEND_URL.replace('ws://', 'http://').replace('wss://', 'https://')}/api/session/${sessionId}/end`, {
      method: 'POST',
    });
    if (!response.ok) {
      throw new Error('Failed to end session');
    }
    return await response.json();
  } catch (error) {
    console.error('Error ending session:', error);
    return null;
  }
};

export const generateReport = async (sessionId: string): Promise<Blob> => {
  try {
    const response = await fetch(`${BACKEND_URL.replace('ws://', 'http://').replace('wss://', 'https://')}/api/report/${sessionId}/generate`, {
      method: 'POST',
    });
    if (!response.ok) {
      throw new Error('Failed to generate report');
    }
    return await response.blob();
  } catch (error) {
    console.error('Error generating report:', error);
    throw error;
  }
};
