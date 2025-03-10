import React, { useRef } from 'react';
import { ImageIcon, Film, X } from 'lucide-react';

interface FileUploaderProps {
  selectedType: 'vibe' | 'banger';
  files: File[];
  previews: string[];
  onFilesSelected: (files: File[]) => void;
  onFileRemove: (index: number) => void;
  onFilesReorder: (from: number, to: number) => void;
}

export function FileUploader({
  selectedType,
  files,
  previews,
  onFilesSelected,
  onFileRemove,
  onFilesReorder
}: FileUploaderProps) {
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    let selectedFiles = Array.from(e.target.files || []);
    
    // Validate files
    if (selectedFiles.length > 0) {
      // For vibes, limit to 10 files total
      if (selectedType === 'vibe') {
        const totalFiles = files.length + selectedFiles.length;
        if (totalFiles > 10) {
          selectedFiles = selectedFiles.slice(0, 10 - files.length);
          alert('Maximum 10 photos allowed. Only first ' + (10 - files.length) + ' photos were added.');
        }
      } else {
        // For bangers, only allow one video
        selectedFiles = [selectedFiles[0]];
      }

      // Validate file types
      selectedFiles = selectedFiles.filter(file => {
        if (selectedType === 'vibe' && !file.type.startsWith('image/')) {
          alert('Please select only image files for vibes');
          return false;
        }
        if (selectedType === 'banger' && !file.type.startsWith('video/')) {
          alert('Please select only video files for bangers');
          return false;
        }
        // Check file size (10MB limit)
        if (file.size > 10 * 1024 * 1024) {
          alert('File size must be less than 10MB');
          return false;
        }
        return true;
      });

      onFilesSelected(selectedFiles);
    }
    // Reset input value to allow selecting the same file again
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    const selectedFiles = Array.from(e.dataTransfer.files);
    handleFileSelect({ target: { files: selectedFiles } } as any);
  };

  return (
    <div>
      {files.length > 0 ? (
        <div className="space-y-4">
          <div className={`grid ${selectedType === 'vibe' ? 'grid-cols-3' : 'grid-cols-1'} gap-2`}>
            {previews.map((preview, index) => (
              <div
                key={index}
                className={`relative ${selectedType === 'vibe' ? 'aspect-square' : 'aspect-[9/16]'}`}
                draggable
                onDragStart={(e) => e.dataTransfer.setData('text/plain', index.toString())}
                onDragOver={(e) => e.preventDefault()}
                onDrop={(e) => {
                  e.preventDefault();
                  const fromIndex = parseInt(e.dataTransfer.getData('text/plain'));
                  onFilesReorder(fromIndex, index);
                }}
              >
                {selectedType === 'vibe' ? (
                  <img
                    src={preview}
                    alt={`Preview ${index + 1}`}
                    className="w-full h-full object-cover rounded-lg bg-black"
                  />
                ) : (
                  <video
                    src={preview}
                    className="w-full h-full object-contain rounded-lg bg-black"
                    controls
                  />
                )}
                <button
                  onClick={() => onFileRemove(index)}
                  className="absolute top-2 right-2 p-2 bg-black bg-opacity-50 rounded-full hover:bg-opacity-75 transition-opacity"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>
            ))}
          </div>

          {selectedType === 'vibe' && files.length < 10 && (
            <button
              onClick={() => fileInputRef.current?.click()}
              className="w-full py-3 border-2 border-dashed border-gray-700 rounded-lg text-gray-400 hover:border-cyan-400 hover:text-cyan-400 transition-colors flex items-center justify-center space-x-2"
            >
              <ImageIcon className="w-5 h-5" />
              <span>Add More ({10 - files.length} remaining)</span>
            </button>
          )}
        </div>
      ) : (
        <div
          className="border-2 border-dashed border-gray-700 rounded-lg p-8 text-center"
          onDragOver={(e) => e.preventDefault()}
          onDrop={handleDrop}
        >
          <input
            ref={fileInputRef}
            type="file"
            accept={selectedType === 'vibe' ? 'image/*' : 'video/*'}
            onChange={handleFileSelect}
            multiple={selectedType === 'vibe'}
            className="hidden"
          />

          <div className="max-w-sm mx-auto">
            <div className="w-16 h-16 mx-auto mb-4">
              {selectedType === 'vibe' ? (
                <ImageIcon className="w-full h-full text-cyan-400" />
              ) : (
                <Film className="w-full h-full text-cyan-400" />
              )}
            </div>

            <h3 className="text-lg font-semibold mb-2">
              {selectedType === 'vibe' ? 'Upload Photos' : 'Upload Video'}
            </h3>

            <p className="text-gray-400 mb-4">
              {selectedType === 'vibe'
                ? 'Share up to 10 photos in one post'
                : 'Create a video up to 90 seconds'}
            </p>

            <button
              onClick={() => fileInputRef.current?.click()}
              className="bg-cyan-400 text-gray-900 px-6 py-2 rounded-lg font-semibold hover:bg-cyan-300 transition-colors"
              title={selectedType === 'vibe' ? 'Select up to 10 photos' : 'Select a video'}
            >
              Select Files
            </button>

            <p className="mt-4 text-sm text-gray-500">
              Or drag and drop files here
            </p>
          </div>
        </div>
      )}
    </div>
  );
}