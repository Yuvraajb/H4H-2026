// Voice Pipeline Service - Workstream B
// This service orchestrates the voice input/output pipeline

import { startListening, stopListening, isCurrentlyListening } from './voiceInput';
import { speak, stopSpeaking, isCurrentlySpeaking } from './voiceOutput';
import { VoiceState } from '../types';

export interface VoicePipelineCallbacks {
  onStateChange: (state: VoiceState) => void;
  onTranscript: (text: string) => void;
  onError: (error: Error) => void;
}

class VoicePipeline {
  private state: VoiceState = 'IDLE';
  private callbacks: VoicePipelineCallbacks | null = null;
  private listeningMode: 'push-to-talk' | 'continuous' = 'push-to-talk';

  setCallbacks(callbacks: VoicePipelineCallbacks): void {
    this.callbacks = callbacks;
  }

  setState(newState: VoiceState): void {
    if (this.state !== newState) {
      this.state = newState;
      this.callbacks?.onStateChange(newState);
      console.log('Voice pipeline state changed to:', newState);
    }
  }

  getState(): VoiceState {
    return this.state;
  }

  setListeningMode(mode: 'push-to-talk' | 'continuous'): void {
    this.listeningMode = mode;
    console.log('Listening mode set to:', mode);
  }

  async startListening(): Promise<void> {
    if (this.state === 'SPEAKING') {
      stopSpeaking();
    }

    if (this.state === 'LISTENING') {
      console.warn('Already listening');
      return;
    }

    this.setState('LISTENING');

    startListening({
      onTranscript: (text: string) => {
        this.callbacks?.onTranscript(text);
        if (this.listeningMode === 'push-to-talk') {
          this.setState('IDLE');
          stopListening();
        }
      },
      onError: (error: Error) => {
        this.callbacks?.onError(error);
        this.setState('IDLE');
      },
    });
  }

  stopListening(): void {
    if (this.state === 'LISTENING') {
      stopListening();
      this.setState('IDLE');
    }
  }

  async speak(text: string): Promise<void> {
    if (this.state === 'LISTENING') {
      this.stopListening();
    }

    this.setState('SPEAKING');

    try {
      await speak(text);
      this.setState('IDLE');
    } catch (error) {
      this.callbacks?.onError(error as Error);
      this.setState('IDLE');
    }
  }

  interrupt(): void {
    stopSpeaking();
    stopListening();
    this.setState('IDLE');
  }

  isActive(): boolean {
    return this.state !== 'IDLE';
  }
}

export const voicePipeline = new VoicePipeline();
