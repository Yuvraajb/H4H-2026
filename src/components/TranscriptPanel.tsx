import React from 'react';
import { useSession } from '../context/SessionContext';

const TranscriptPanel: React.FC = () => {
  const { session } = useSession();

  return (
    <div className="border-4 border-cyan-500 p-6 rounded-lg bg-cyan-900/20 min-w-[400px] max-w-[600px] max-h-[500px] overflow-y-auto">
      <h2 className="text-xl font-bold mb-4">Transcript Panel</h2>
      <p className="text-sm mb-4">Workstream A — Placeholder Component</p>
      <div className="space-y-2">
        {session?.transcript.map((entry) => (
          <div
            key={entry.id}
            className={`p-3 rounded ${
              entry.speaker === 'user' ? 'bg-blue-800/30' : 'bg-green-800/30'
            }`}
          >
            <p className="text-xs font-semibold mb-1">
              {entry.speaker === 'user' ? 'You' : 'AI'}
            </p>
            <p className="text-sm">{entry.text}</p>
          </div>
        ))}
      </div>
    </div>
  );
};

export default TranscriptPanel;
