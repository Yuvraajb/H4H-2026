import { useState, useEffect, useCallback } from 'react';
import { voicePipeline, VoicePipelineCallbacks } from '../services/voicePipeline';
import { VoiceState } from '../types';

export const useVoicePipeline = () => {
  const [state, setState] = useState<VoiceState>('IDLE');
  const [isRecording, setIsRecording] = useState(false);
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTranscript, setCurrentTranscript] = useState('');

  useEffect(() => {
    const callbacks: VoicePipelineCallbacks = {
      onStateChange: (newState: VoiceState) => {
        setState(newState);
        setIsRecording(newState === 'LISTENING');
        setIsPlaying(newState === 'SPEAKING');
      },
      onTranscript: (text: string) => {
        setCurrentTranscript(text);
      },
      onError: (error: Error) => {
        console.error('Voice pipeline error:', error);
      },
    };

    voicePipeline.setCallbacks(callbacks);

    return () => {
      voicePipeline.interrupt();
    };
  }, []);

  const startListening = useCallback(async () => {
    await voicePipeline.startListening();
  }, []);

  const stopListening = useCallback(() => {
    voicePipeline.stopListening();
  }, []);

  const speak = useCallback(async (text: string) => {
    await voicePipeline.speak(text);
  }, []);

  const interrupt = useCallback(() => {
    voicePipeline.interrupt();
  }, []);

  const setListeningMode = useCallback((mode: 'push-to-talk' | 'continuous') => {
    voicePipeline.setListeningMode(mode);
  }, []);

  return {
    state,
    isRecording,
    isPlaying,
    currentTranscript,
    startListening,
    stopListening,
    speak,
    interrupt,
    setListeningMode,
  };
};
