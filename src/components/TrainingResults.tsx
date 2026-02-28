import React from 'react';
import { useSession } from '../context/SessionContext';

const TrainingResults: React.FC = () => {
  const { trainingScore } = useSession();

  if (!trainingScore) {
    return (
      <div className="border-4 border-teal-500 p-6 rounded-lg bg-teal-900/20 min-w-[400px]">
        <h2 className="text-xl font-bold mb-4">Training Results</h2>
        <p className="text-sm mb-2">Workstream E — Placeholder Component</p>
        <p className="text-gray-400">No training results yet</p>
      </div>
    );
  }

  return (
    <div className="border-4 border-teal-500 p-6 rounded-lg bg-teal-900/20 min-w-[400px]">
      <h2 className="text-xl font-bold mb-4">Training Results</h2>
      <p className="text-sm mb-4">Workstream E — Placeholder Component</p>
      <div className="space-y-4">
        <div>
          <p className="text-2xl font-bold">Score: {trainingScore.overall}%</p>
        </div>
        <div>
          <p className="font-semibold mb-2">Correct Actions:</p>
          <ul className="list-disc list-inside text-sm space-y-1">
            {trainingScore.correct_actions.map((action, idx) => (
              <li key={idx} className="text-green-400">{action}</li>
            ))}
          </ul>
        </div>
        <div>
          <p className="font-semibold mb-2">Missed Actions:</p>
          <ul className="list-disc list-inside text-sm space-y-1">
            {trainingScore.missed_actions.map((action, idx) => (
              <li key={idx} className="text-red-400">{action}</li>
            ))}
          </ul>
        </div>
        <div>
          <p className="font-semibold mb-2">Feedback:</p>
          <p className="text-sm">{trainingScore.feedback}</p>
        </div>
      </div>
    </div>
  );
};

export default TrainingResults;
