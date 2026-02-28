import React, { useEffect } from 'react';
import { SessionProvider } from './context/SessionContext';
import LandingScreen from './components/LandingScreen';
import HUDPanel from './components/HUDPanel';
import ImagePanel from './components/ImagePanel';
import TranscriptPanel from './components/TranscriptPanel';
import ControlPanel from './components/ControlPanel';
import TrainingMode from './components/TrainingMode';
import TrainingResults from './components/TrainingResults';
import { useSession } from './context/SessionContext';

// WebSpatial initialization placeholder
// Workstream A will implement proper WebSpatial scene setup
const initializeWebSpatial = () => {
  console.log('WebSpatial initialization - Workstream A will implement');
  // TODO: Initialize WebSpatial scene and position panels
};

const AppContent: React.FC = () => {
  const { isSessionActive, mode } = useSession();

  useEffect(() => {
    initializeWebSpatial();
  }, []);

  if (!isSessionActive) {
    return <LandingScreen />;
  }

  return (
    <div className="w-full h-screen bg-gray-900 p-8 overflow-auto">
      <div className="max-w-7xl mx-auto">
        <h1 className="text-3xl font-bold text-white mb-6">GuideVR</h1>
        
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {/* HUD Panel */}
          <div className="col-span-1">
            <HUDPanel />
          </div>

          {/* Image Panel */}
          <div className="col-span-1">
            <ImagePanel />
          </div>

          {/* Transcript Panel */}
          <div className="col-span-1 lg:col-span-2">
            <TranscriptPanel />
          </div>

          {/* Control Panel */}
          <div className="col-span-1">
            <ControlPanel />
          </div>

          {/* Training Mode (only shown in training mode) */}
          {mode === 'training' && (
            <>
              <div className="col-span-1">
                <TrainingMode />
              </div>
              <div className="col-span-1">
                <TrainingResults />
              </div>
            </>
          )}
        </div>

        <div className="mt-8 p-4 bg-gray-800 rounded text-sm text-gray-400">
          <p>Note: This is a placeholder layout. Workstream A will implement proper WebSpatial spatial positioning.</p>
        </div>
      </div>
    </div>
  );
};

const App: React.FC = () => {
  return (
    <SessionProvider>
      <AppContent />
    </SessionProvider>
  );
};

export default App;
