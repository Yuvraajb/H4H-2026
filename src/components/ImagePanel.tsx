import React from 'react';
import { useSession } from '../context/SessionContext';

const ImagePanel: React.FC = () => {
  const { currentImage } = useSession();

  return (
    <div className="border-4 border-purple-500 p-6 rounded-lg bg-purple-900/20 min-w-[300px] max-w-[500px]">
      <h2 className="text-xl font-bold mb-4">Image Panel</h2>
      <p className="text-sm mb-2">Workstream A — Placeholder Component</p>
      {currentImage ? (
        <div className="mt-4">
          <img src={currentImage} alt="Instruction" className="w-full rounded" />
        </div>
      ) : (
        <div className="mt-4 p-8 bg-gray-800 rounded text-center text-gray-400">
          No image displayed
        </div>
      )}
    </div>
  );
};

export default ImagePanel;
