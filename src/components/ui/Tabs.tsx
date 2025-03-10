import React from 'react';

interface TabsProps {
  defaultValue: string;
  value?: string;
  onChange?: (value: string) => void;
  children: React.ReactNode;
  className?: string;
}

interface TabsTriggerProps {
  value: string;
  children: React.ReactNode;
  className?: string;
}

interface TabsContentProps {
  value: string;
  children: React.ReactNode;
}

export function Tabs({ defaultValue, value, onChange, children, className = '' }: TabsProps) {
  const [activeTab, setActiveTab] = React.useState(defaultValue);

  const currentValue = value !== undefined ? value : activeTab;

  const handleTabChange = (newValue: string) => {
    setActiveTab(newValue);
    onChange?.(newValue);
  };

  const contextValue = React.useMemo(() => ({
    value: currentValue,
    onChange: handleTabChange
  }), [currentValue]);

  return (
    <div className={className} data-state={currentValue}>
      <TabsContext.Provider value={contextValue}>
        {children}
      </TabsContext.Provider>
    </div>
  );
}

const TabsContext = React.createContext<{
  value: string;
  onChange: (value: string) => void;
}>({ value: '', onChange: () => {} });

export function TabsList({ children, className = '' }: { children: React.ReactNode; className?: string }) {
  return (
    <div className={`flex ${className}`}>
      {children}
    </div>
  );
}

export function TabsTrigger({ value, children, className = '' }: TabsTriggerProps) {
  const { value: currentValue, onChange } = React.useContext(TabsContext);
  const isActive = currentValue === value;

  return (
    <button
      onClick={() => onChange(value)}
      className={`px-3 sm:px-4 py-2 text-sm font-medium rounded-md hover:bg-gray-800 focus:outline-none focus:ring-2 focus:ring-cyan-400 ${
        isActive ? 'bg-cyan-400 text-gray-900' : 'text-gray-400'
      } ${className}`}
    >
      {children}
    </button>
  );
}

export function TabsContent({ value, children }: TabsContentProps) {
  const { value: currentValue } = React.useContext(TabsContext);
  const isActive = currentValue === value;

  return (
    <div className={isActive ? 'block' : 'hidden'}>
      {children}
    </div>
  );
}