import React from 'react';
import { useSession } from '../context/SessionContext';

const ControlPanel: React.FC = () => {
  const { isSessionActive, startSession, endSession } = useSession();

  return (
    <div className="border-4 border-pink-500 p-6 rounded-lg bg-pink-900/20 min-w-[250px]">
      <h2 className="text-xl font-bold mb-4">Control Panel</h2>
      <p className="text-sm mb-4">Workstream A — Placeholder Component</p>
      <div className="space-y-2">
        {!isSessionActive ? (
          <button
            onClick={() => startSession('live')}
            className="w-full px-4 py-2 bg-green-600 hover:bg-green-700 rounded text-white font-semibold"
          >
            Start Session
          </button>
        ) : (
          <button
            onClick={endSession}
            className="w-full px-4 py-2 bg-red-600 hover:bg-red-700 rounded text-white font-semibold"
          >
            End Session
          </button>
        )}
      </div>
    </div>
  );
};

export default ControlPanel;
