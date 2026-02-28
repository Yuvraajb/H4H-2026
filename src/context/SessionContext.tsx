import React, { createContext, useContext, useState, ReactNode } from 'react';
import { Session, SessionMode, TranscriptEntry, ResponseMetadata, UrgencyLevel, TrainingScenario, TrainingScore } from '../types';

interface SessionContextType {
  session: Session | null;
  currentUrgency: UrgencyLevel;
  currentImage: string | null;
  isSessionActive: boolean;
  mode: SessionMode;
  trainingScore: TrainingScore | null;
  startSession: (mode: SessionMode, scenario?: string) => void;
  endSession: () => void;
  addTranscriptEntry: (entry: TranscriptEntry) => void;
  updateUrgency: (urgency: UrgencyLevel) => void;
  setCurrentImage: (url: string | null) => void;
  setTrainingScore: (score: TrainingScore) => void;
}

const SessionContext = createContext<SessionContextType | undefined>(undefined);

// Mock data for development
const mockSession: Session = {
  id: 'mock-session-123',
  mode: 'live',
  startTime: new Date().toISOString(),
  transcript: [
    {
      id: '1',
      speaker: 'user',
      text: 'Someone collapsed, what should I do?',
      timestamp: new Date().toISOString(),
    },
    {
      id: '2',
      speaker: 'ai',
      text: 'Stay calm. First, check if the person is responsive. Tap their shoulder and ask loudly, "Are you okay?"',
      timestamp: new Date().toISOString(),
    },
  ],
  metadata: [
    {
      step: 1,
      urgency: 'high',
      image_query: 'check responsiveness first aid',
      category: 'assessment',
      display_text: 'Step 1: Check Responsiveness',
    },
  ],
};

export const SessionProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [session, setSession] = useState<Session | null>(mockSession);
  const [currentUrgency, setCurrentUrgency] = useState<UrgencyLevel>('medium');
  const [currentImage, setCurrentImage] = useState<string | null>(null);
  const [isSessionActive, setIsSessionActive] = useState<boolean>(true);
  const [mode, setMode] = useState<SessionMode>('live');
  const [trainingScore, setTrainingScore] = useState<TrainingScore | null>(null);

  const startSession = (newMode: SessionMode, scenario?: string) => {
    const newSession: Session = {
      id: `session-${Date.now()}`,
      mode: newMode,
      startTime: new Date().toISOString(),
      transcript: [],
      metadata: [],
      scenario,
    };
    setSession(newSession);
    setIsSessionActive(true);
    setMode(newMode);
    setCurrentUrgency('medium');
    setCurrentImage(null);
    setTrainingScore(null);
  };

  const endSession = () => {
    if (session) {
      setSession({
        ...session,
        endTime: new Date().toISOString(),
      });
    }
    setIsSessionActive(false);
  };

  const addTranscriptEntry = (entry: TranscriptEntry) => {
    if (session) {
      setSession({
        ...session,
        transcript: [...session.transcript, entry],
      });
    }
  };

  const updateUrgency = (urgency: UrgencyLevel) => {
    setCurrentUrgency(urgency);
  };

  const setCurrentImageHandler = (url: string | null) => {
    setCurrentImage(url);
  };

  const setTrainingScoreHandler = (score: TrainingScore) => {
    setTrainingScore(score);
  };

  return (
    <SessionContext.Provider
      value={{
        session,
        currentUrgency,
        currentImage,
        isSessionActive,
        mode,
        trainingScore,
        startSession,
        endSession,
        addTranscriptEntry,
        updateUrgency,
        setCurrentImage: setCurrentImageHandler,
        setTrainingScore: setTrainingScoreHandler,
      }}
    >
      {children}
    </SessionContext.Provider>
  );
};

export const useSession = () => {
  const context = useContext(SessionContext);
  if (context === undefined) {
    throw new Error('useSession must be used within a SessionProvider');
  }
  return context;
};
