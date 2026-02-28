import React, { useState } from 'react';
import { useSession } from '../context/SessionContext';
import { TrainingScenario } from '../types';

const mockScenarios: TrainingScenario[] = [
  { id: '1', name: 'CPR', description: 'Practice CPR on a collapsed person', difficulty: 'medium' },
  { id: '2', name: 'Choking', description: 'Help someone who is choking', difficulty: 'easy' },
  { id: '3', name: 'Bleeding', description: 'Control severe bleeding', difficulty: 'hard' },
];

const TrainingMode: React.FC = () => {
  const { startSession } = useSession();
  const [selectedScenario, setSelectedScenario] = useState<string>('');

  const handleStartTraining = () => {
    if (selectedScenario) {
      startSession('training', selectedScenario);
    }
  };

  return (
    <div className="border-4 border-indigo-500 p-6 rounded-lg bg-indigo-900/20 min-w-[400px]">
      <h2 className="text-xl font-bold mb-4">Training Mode</h2>
      <p className="text-sm mb-4">Workstream E — Placeholder Component</p>
      <div className="space-y-4">
        <div>
          <label className="block text-sm font-semibold mb-2">Select Scenario:</label>
          <select
            value={selectedScenario}
            onChange={(e) => setSelectedScenario(e.target.value)}
            className="w-full px-3 py-2 bg-gray-800 border border-gray-600 rounded text-white"
          >
            <option value="">Choose a scenario...</option>
            {mockScenarios.map((scenario) => (
              <option key={scenario.id} value={scenario.id}>
                {scenario.name} ({scenario.difficulty})
              </option>
            ))}
          </select>
        </div>
        <button
          onClick={handleStartTraining}
          disabled={!selectedScenario}
          className="w-full px-4 py-2 bg-indigo-600 hover:bg-indigo-700 disabled:bg-gray-600 disabled:cursor-not-allowed rounded text-white font-semibold"
        >
          Start Training
        </button>
      </div>
    </div>
  );
};

export default TrainingMode;
