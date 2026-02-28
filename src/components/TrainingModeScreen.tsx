import React, { useState } from 'react';
import { useSession } from '../context/SessionContext';

const TRAINING_MODES = [
  { id: 'cpr', name: 'CPR', description: 'Cardiopulmonary resuscitation' },
  { id: 'bleeding', name: 'Bleeding', description: 'Control severe bleeding' },
  { id: 'choking', name: 'Choking', description: 'Help someone who is choking' },
  { id: 'burn', name: 'Burn', description: 'First aid for burns' },
] as const;

const SCENARIOS_BY_MODE: Record<string, { id: string; name: string }[]> = {
  cpr: [
    { id: 'cpr-adult', name: 'Adult collapsed (no pulse)' },
    { id: 'cpr-child', name: 'Child unresponsive' },
  ],
  bleeding: [
    { id: 'bleeding-arm', name: 'Severe cut on arm' },
    { id: 'bleeding-leg', name: 'Leg wound with heavy bleeding' },
  ],
  choking: [
    { id: 'choking-adult', name: 'Adult choking (conscious)' },
    { id: 'choking-infant', name: 'Infant choking' },
  ],
  burn: [
    { id: 'burn-thermal', name: 'Thermal burn (hot surface)' },
    { id: 'burn-chemical', name: 'Chemical burn' },
  ],
};

type Phase = 'select' | 'running' | 'results';

const PLACEHOLDER_SCORE = {
  overall: 78,
  correct_actions: ['Checked responsiveness', 'Called for help', 'Started compressions within 1 min'],
  missed_actions: ['Did not tilt head for breaths', 'Compression depth slightly shallow'],
  feedback: 'Good overall response. Focus on head tilt for rescue breaths and aim for 2–2.4" compression depth next time.',
};

const TrainingModeScreen: React.FC = () => {
  const { setView, endSession, startSession, setTrainingScore } = useSession();
  const [phase, setPhase] = useState<Phase>('select');
  const [selectedMode, setSelectedMode] = useState<string>('');
  const [selectedScenario, setSelectedScenario] = useState<string>('');

  const scenarios = selectedMode ? SCENARIOS_BY_MODE[selectedMode] ?? [] : [];

  const handleStartSession = () => {
    if (!selectedMode || !selectedScenario) return;
    startSession('training', selectedScenario);
    setPhase('running');
  };

  const handleCompleteScenario = () => {
    setTrainingScore(PLACEHOLDER_SCORE);
    setPhase('results');
  };

  const handleBackToHome = () => {
    setView('landing');
    endSession();
  };

  const handleTryAgain = () => {
    setPhase('select');
    setSelectedMode('');
    setSelectedScenario('');
  };

  if (phase === 'results') {
    const score = PLACEHOLDER_SCORE;
    return (
      <div className="w-full h-screen flex items-center justify-center bg-gray-900 text-white p-6">
        <div className="max-w-lg w-full border-4 border-teal-500 rounded-xl bg-gray-800/80 p-8 shadow-xl">
          <h1 className="text-2xl font-bold mb-6 text-teal-400">Training complete</h1>

          <div className="space-y-6">
            <div className="text-center p-4 bg-gray-700/50 rounded-lg">
              <p className="text-sm text-gray-400 uppercase tracking-wide mb-1">Score</p>
              <p className="text-4xl font-bold text-white">{score.overall}%</p>
            </div>

            <div>
              <p className="text-sm font-semibold text-gray-300 mb-2">Correct actions</p>
              <ul className="list-disc list-inside text-sm space-y-1 text-green-400">
                {score.correct_actions.map((action, i) => (
                  <li key={i}>{action}</li>
                ))}
              </ul>
            </div>

            <div>
              <p className="text-sm font-semibold text-gray-300 mb-2">Missed actions</p>
              <ul className="list-disc list-inside text-sm space-y-1 text-red-400">
                {score.missed_actions.map((action, i) => (
                  <li key={i}>{action}</li>
                ))}
              </ul>
            </div>

            <div>
              <p className="text-sm font-semibold text-gray-300 mb-2">Feedback</p>
              <p className="text-sm text-gray-200 bg-gray-700/50 p-3 rounded-lg">{score.feedback}</p>
            </div>
          </div>

          <div className="flex gap-3 mt-8">
            <button
              onClick={handleTryAgain}
              className="flex-1 px-4 py-3 bg-indigo-600 hover:bg-indigo-700 rounded-lg font-semibold"
            >
              Try another scenario
            </button>
            <button
              onClick={handleBackToHome}
              className="flex-1 px-4 py-3 bg-gray-600 hover:bg-gray-700 rounded-lg font-semibold"
            >
              Back to home
            </button>
          </div>
        </div>
      </div>
    );
  }

  if (phase === 'running') {
    return (
      <div className="w-full h-screen flex items-center justify-center bg-gray-900 text-white p-6">
        <div className="max-w-md w-full border-4 border-amber-500 rounded-xl bg-gray-800/80 p-8 text-center">
          <h1 className="text-2xl font-bold mb-2">Scenario in progress</h1>
          <p className="text-gray-400 text-sm mb-6">
            {TRAINING_MODES.find((m) => m.id === selectedMode)?.name} — placeholder
          </p>
          <p className="text-gray-500 text-sm mb-6">
            (Voice and AI guidance would run here.)
          </p>
          <button
            onClick={handleCompleteScenario}
            className="w-full px-4 py-3 bg-amber-600 hover:bg-amber-700 rounded-lg font-semibold"
          >
            Complete scenario
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="w-full h-screen flex items-center justify-center bg-gray-900 text-white p-6 overflow-auto">
      <div className="max-w-2xl w-full">
        <div className="flex items-center justify-between mb-8">
          <h1 className="text-2xl font-bold text-indigo-400">Training mode</h1>
          <button
            onClick={handleBackToHome}
            className="text-sm text-gray-400 hover:text-white"
          >
            ← Back to home
          </button>
        </div>

        <p className="text-gray-400 text-sm mb-6">Select a mode, then a scenario. Start when ready.</p>

        <div className="mb-8">
          <p className="text-sm font-semibold text-gray-300 mb-3">1. Select mode</p>
          <div className="grid grid-cols-2 gap-3">
            {TRAINING_MODES.map((mode) => (
              <button
                key={mode.id}
                onClick={() => {
                  setSelectedMode(mode.id);
                  setSelectedScenario('');
                }}
                className={`p-4 rounded-lg border-2 text-left transition-colors ${
                  selectedMode === mode.id
                    ? 'border-indigo-500 bg-indigo-900/30'
                    : 'border-gray-600 bg-gray-800/50 hover:border-gray-500'
                }`}
              >
                <span className="font-semibold block">{mode.name}</span>
                <span className="text-xs text-gray-400">{mode.description}</span>
              </button>
            ))}
          </div>
        </div>

        {selectedMode && (
          <div className="mb-8">
            <p className="text-sm font-semibold text-gray-300 mb-3">2. Select scenario</p>
            <div className="space-y-2">
              {scenarios.map((s) => (
                <button
                  key={s.id}
                  onClick={() => setSelectedScenario(s.id)}
                  className={`w-full p-3 rounded-lg border-2 text-left transition-colors ${
                    selectedScenario === s.id
                      ? 'border-indigo-500 bg-indigo-900/30'
                      : 'border-gray-600 bg-gray-800/50 hover:border-gray-500'
                  }`}
                >
                  {s.name}
                </button>
              ))}
            </div>
          </div>
        )}

        <button
          onClick={handleStartSession}
          disabled={!selectedMode || !selectedScenario}
          className="w-full px-4 py-3 bg-indigo-600 hover:bg-indigo-700 disabled:bg-gray-700 disabled:cursor-not-allowed rounded-lg font-semibold"
        >
          Start session
        </button>
      </div>
    </div>
  );
};

export default TrainingModeScreen;
