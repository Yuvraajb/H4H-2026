// Voice Input Service - Workstream B
// This service handles microphone input and speech-to-text

export interface VoiceInputCallbacks {
  onTranscript: (text: string) => void;
  onError: (error: Error) => void;
}

let recognition: any = null;
let isListening = false;

export const initializeVoiceInput = (): boolean => {
  // Check for browser support
  if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
    console.warn('Speech recognition not supported in this browser');
    return false;
  }

  const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
  recognition = new SpeechRecognition();
  
  recognition.continuous = false;
  recognition.interimResults = false;
  recognition.lang = 'en-US';

  return true;
};

export const startListening = (callbacks: VoiceInputCallbacks): void => {
  if (!recognition) {
    if (!initializeVoiceInput()) {
      callbacks.onError(new Error('Speech recognition not available'));
      return;
    }
  }

  if (isListening) {
    console.warn('Already listening');
    return;
  }

  recognition.onresult = (event: any) => {
    const transcript = event.results[0][0].transcript;
    console.log('Voice input transcript:', transcript);
    callbacks.onTranscript(transcript);
  };

  recognition.onerror = (event: any) => {
    console.error('Speech recognition error:', event.error);
    callbacks.onError(new Error(event.error));
    isListening = false;
  };

  recognition.onend = () => {
    isListening = false;
    console.log('Speech recognition ended');
  };

  try {
    recognition.start();
    isListening = true;
    console.log('Started listening for voice input');
  } catch (error) {
    console.error('Error starting speech recognition:', error);
    callbacks.onError(error as Error);
    isListening = false;
  }
};

export const stopListening = (): void => {
  if (recognition && isListening) {
    recognition.stop();
    isListening = false;
    console.log('Stopped listening for voice input');
  }
};

export const isCurrentlyListening = (): boolean => {
  return isListening;
};
