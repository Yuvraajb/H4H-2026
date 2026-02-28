import React from 'react';
import { useSession } from '../context/SessionContext';

const LandingScreen: React.FC = () => {
  const { startSession, setView } = useSession();

  return (
    <div className="w-full h-screen flex items-center justify-center bg-gray-900 text-white">
      <div className="border-4 border-blue-500 p-8 rounded-lg bg-blue-900/20 max-w-md w-full text-center">
        <h1 className="text-2xl font-bold mb-2">GuideVR</h1>
        <p className="text-sm text-gray-300 mb-6">Choose how to start</p>
        <div className="flex flex-col gap-3">
          <button
            onClick={() => {
              startSession('live');
              setView('session');
            }}
            className="w-full px-4 py-3 bg-blue-600 hover:bg-blue-700 rounded-lg font-semibold"
          >
            Start session (Live)
          </button>
          <button
            onClick={() => setView('training')}
            className="w-full px-4 py-3 bg-indigo-600 hover:bg-indigo-700 rounded-lg font-semibold"
          >
            Training mode
          </button>
        </div>
      </div>
    </div>
  );
};

export default LandingScreen;
