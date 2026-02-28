// Voice Output Service - Workstream B
// This service handles text-to-speech using ElevenLabs API

const ELEVENLABS_API_KEY = import.meta.env.VITE_ELEVENLABS_API_KEY || '';
const ELEVENLABS_VOICE_ID = import.meta.env.VITE_ELEVENLABS_VOICE_ID || 'default';

let currentAudio: HTMLAudioElement | null = null;

export interface VoiceOutputOptions {
  voiceId?: string;
  stability?: number;
  similarityBoost?: number;
}

export const speak = async (
  text: string,
  options: VoiceOutputOptions = {}
): Promise<void> => {
  // Stop any currently playing audio
  stopSpeaking();

  if (!ELEVENLABS_API_KEY) {
    console.warn('ElevenLabs API key not set, using browser TTS fallback');
    return speakWithBrowserTTS(text);
  }

  try {
    const voiceId = options.voiceId || ELEVENLABS_VOICE_ID;
    const response = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,
      {
        method: 'POST',
        headers: {
          'Accept': 'audio/mpeg',
          'Content-Type': 'application/json',
          'xi-api-key': ELEVENLABS_API_KEY,
        },
        body: JSON.stringify({
          text,
          model_id: 'eleven_monolingual_v1',
          voice_settings: {
            stability: options.stability || 0.5,
            similarity_boost: options.similarityBoost || 0.5,
          },
        }),
      }
    );

    if (!response.ok) {
      throw new Error(`ElevenLabs API error: ${response.statusText}`);
    }

    const audioBlob = await response.blob();
    const audioUrl = URL.createObjectURL(audioBlob);
    currentAudio = new Audio(audioUrl);
    
    await new Promise<void>((resolve, reject) => {
      if (!currentAudio) {
        reject(new Error('Audio element not created'));
        return;
      }

      currentAudio.onended = () => {
        URL.revokeObjectURL(audioUrl);
        currentAudio = null;
        resolve();
      };

      currentAudio.onerror = (error) => {
        URL.revokeObjectURL(audioUrl);
        currentAudio = null;
        reject(error);
      };

      currentAudio.play();
    });
  } catch (error) {
    console.error('Error with ElevenLabs TTS:', error);
    // Fallback to browser TTS
    return speakWithBrowserTTS(text);
  }
};

const speakWithBrowserTTS = (text: string): void => {
  if ('speechSynthesis' in window) {
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = 'en-US';
    utterance.rate = 1.0;
    utterance.pitch = 1.0;
    utterance.volume = 1.0;
    
    window.speechSynthesis.speak(utterance);
    console.log('Using browser TTS fallback');
  } else {
    console.warn('Browser TTS not available');
  }
};

export const stopSpeaking = (): void => {
  if (currentAudio) {
    currentAudio.pause();
    currentAudio = null;
  }
  
  if ('speechSynthesis' in window) {
    window.speechSynthesis.cancel();
  }
};

export const isCurrentlySpeaking = (): boolean => {
  return currentAudio !== null || window.speechSynthesis.speaking;
};
