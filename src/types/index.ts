// Session and Response Types

export type SessionMode = 'live' | 'training';

export type UrgencyLevel = 'low' | 'medium' | 'high' | 'critical';

export interface ResponseMetadata {
  step: number;
  urgency: UrgencyLevel;
  image_query: string | null;
  category: string;
  display_text: string;
}

export interface AIResponse {
  text: string;
  metadata: ResponseMetadata;
}

export interface TranscriptEntry {
  id: string;
  speaker: 'user' | 'ai';
  text: string;
  timestamp: string;
}

export interface Session {
  id: string;
  mode: SessionMode;
  startTime: string;
  endTime?: string;
  transcript: TranscriptEntry[];
  metadata: ResponseMetadata[];
  scenario?: string;
}

// WebSocket Message Types

export type WebSocketMessageType = 
  | 'start_session'
  | 'utterance'
  | 'end_session'
  | 'session_started'
  | 'response'
  | 'training_complete'
  | 'session_ended'
  | 'error';

export interface StartSessionMessage {
  type: 'start_session';
  mode: SessionMode;
  scenario?: string;
}

export interface UtteranceMessage {
  type: 'utterance';
  text: string;
  timestamp: string;
}

export interface EndSessionMessage {
  type: 'end_session';
}

export interface SessionStartedMessage {
  type: 'session_started';
  session_id: string;
}

export interface ResponseMessage {
  type: 'response';
  text: string;
  metadata: ResponseMetadata;
}

export interface TrainingCompleteMessage {
  type: 'training_complete';
  score: {
    overall: number;
    correct_actions: string[];
    missed_actions: string[];
    feedback: string;
  };
}

export interface SessionEndedMessage {
  type: 'session_ended';
  session_id: string;
}

export interface ErrorMessage {
  type: 'error';
  message: string;
}

export type ClientMessage = StartSessionMessage | UtteranceMessage | EndSessionMessage;
export type ServerMessage = 
  | SessionStartedMessage 
  | ResponseMessage 
  | TrainingCompleteMessage 
  | SessionEndedMessage 
  | ErrorMessage;

// Image Service Types

export interface ImageResult {
  image_url: string;
  caption: string;
  source: string;
}

// Voice Pipeline Types

export type VoiceState = 'IDLE' | 'LISTENING' | 'PROCESSING' | 'SPEAKING';

export interface VoicePipelineState {
  state: VoiceState;
  isRecording: boolean;
  isPlaying: boolean;
  currentTranscript: string;
}

// Training Types

export interface TrainingScenario {
  id: string;
  name: string;
  description: string;
  difficulty: 'easy' | 'medium' | 'hard';
}

export interface TrainingScore {
  overall: number;
  correct_actions: string[];
  missed_actions: string[];
  feedback: string;
}
