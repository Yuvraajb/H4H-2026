import React from 'react';
import { useSession } from '../context/SessionContext';

const HUDPanel: React.FC = () => {
  const { currentUrgency, session } = useSession();

  const urgencyColors = {
    low: 'border-green-500 bg-green-900/20',
    medium: 'border-yellow-500 bg-yellow-900/20',
    high: 'border-orange-500 bg-orange-900/20',
    critical: 'border-red-500 bg-red-900/20',
  };

  return (
    <div className={`border-4 ${urgencyColors[currentUrgency]} p-6 rounded-lg min-w-[300px] max-w-[400px]`}>
      <h2 className="text-xl font-bold mb-4">HUD Panel</h2>
      <p className="text-sm mb-2">Workstream A — Placeholder Component</p>
      <div className="mt-4">
        <p className="text-sm">Current Urgency: <span className="font-bold">{currentUrgency}</span></p>
        <p className="text-sm mt-2">Session: {session?.id || 'None'}</p>
      </div>
    </div>
  );
};

export default HUDPanel;
