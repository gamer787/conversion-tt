import React from 'react';
import { Bell, Shield, Smartphone, Moon, HelpCircle, LogOut, ChevronLeft, FileText } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { signOut } from '../lib/auth';
import { NotificationSettings } from '../components/settings/NotificationSettings';
import { ConnectionSettings } from '../components/settings/ConnectionSettings';

type SettingSection = 'main' | 'notifications' | 'privacy' | 'bluetooth' | 'appearance' | 'help';

function Settings() {
  const navigate = useNavigate();
  const [activeSection, setActiveSection] = React.useState<SettingSection>('main');

  const settingsSections = [
    {
      id: 'notifications',
      icon: <Bell className="w-6 h-6" />,
      title: 'Notifications',
      description: 'Manage your notification preferences'
    },
    {
      id: 'privacy',
      icon: <Shield className="w-6 h-6" />,
      title: 'Privacy',
      description: 'Control your account privacy settings'
    },
    {
      id: 'bluetooth',
      icon: <Smartphone className="w-6 h-6" />,
      title: 'Connection Settings',
      description: 'Manage Bluetooth and NFC settings'
    },
    {
      id: 'appearance',
      icon: <Moon className="w-6 h-6" />,
      title: 'Appearance',
      description: 'Customize your app theme'
    },
    {
      id: 'help',
      icon: <HelpCircle className="w-6 h-6" />,
      title: 'Help & Support',
      description: 'Get help and contact support'
    },
    {
      id: 'legal',
      icon: <FileText className="w-6 h-6" />,
      title: 'Terms & Policies',
      description: 'View our terms and privacy policies'
    }
  ];

  const handleLogout = async () => {
    try {
      await signOut();
      navigate('/'); // Redirect to home page after logout
    } catch (error) {
      console.error('Error logging out:', error);
    }
  };

  return (
    <div className="pb-20 pt-4">
      {activeSection === 'main' ? (
        <>
          <h1 className="text-2xl font-bold mb-6">Settings</h1>

          <div className="space-y-2">
            {settingsSections.map((section) => (
              <button
                key={section.id}
                onClick={() => setActiveSection(section.id as SettingSection)}
                className="w-full flex items-center p-4 bg-gray-900 rounded-lg hover:bg-gray-800 transition-colors text-left"
              >
                <div className="text-cyan-400">{section.icon}</div>
                <div className="ml-4">
                  <h3 className="font-semibold">{section.title}</h3>
                  <p className="text-sm text-gray-400">{section.description}</p>
                </div>
              </button>
            ))}

            <button 
              onClick={handleLogout}
              className="w-full flex items-center p-4 bg-gray-900 rounded-lg hover:bg-gray-800 transition-colors text-left text-red-500"
            >
              <LogOut className="w-6 h-6" />
              <div className="ml-4">
                <h3 className="font-semibold">Log Out</h3>
                <p className="text-sm text-gray-400">Sign out of your account</p>
              </div>
            </button>
          </div>

          <div className="mt-8 text-center">
            <p className="text-sm text-gray-400">App Version 1.0.0</p>
          </div>
        </>
      ) : (
        <div>
          <div className="flex items-center space-x-3 mb-6">
            <button
              onClick={() => setActiveSection('main')}
              className="p-2 hover:bg-gray-800 rounded-lg transition-colors"
            >
              <ChevronLeft className="w-6 h-6" />
            </button>
            <h1 className="text-2xl font-bold">
              {settingsSections.find(s => s.id === activeSection)?.title}
            </h1>
          </div>

          {activeSection === 'notifications' && <NotificationSettings />}
          {activeSection === 'bluetooth' && <ConnectionSettings />}
          {activeSection === 'legal' && (
            <div className="space-y-4">
              <div className="bg-gray-900 p-4 rounded-lg">
                <h2 className="font-semibold mb-2">Terms of Service</h2>
                <p className="text-gray-400 text-sm mb-4">
                  Our terms of service outline your rights and responsibilities when using our platform.
                </p>
                <a
                  href="/terms"
                  target="_blank"
                  className="inline-flex items-center space-x-2 text-cyan-400 hover:text-cyan-300 transition-colors"
                >
                  <span>Read Terms of Service</span>
                  <FileText className="w-4 h-4" />
                </a>
              </div>

              <div className="bg-gray-900 p-4 rounded-lg">
                <h2 className="font-semibold mb-2">Privacy Policy</h2>
                <p className="text-gray-400 text-sm mb-4">
                  Learn how we collect, use, and protect your personal information.
                </p>
                <a
                  href="/privacy"
                  target="_blank"
                  className="inline-flex items-center space-x-2 text-cyan-400 hover:text-cyan-300 transition-colors"
                >
                  <span>Read Privacy Policy</span>
                  <FileText className="w-4 h-4" />
                </a>
              </div>

              <div className="bg-gray-900 p-4 rounded-lg">
                <h2 className="font-semibold mb-2">Cookie Policy</h2>
                <p className="text-gray-400 text-sm mb-4">
                  Information about how we use cookies and similar technologies.
                </p>
                <a
                  href="/cookies"
                  target="_blank"
                  className="inline-flex items-center space-x-2 text-cyan-400 hover:text-cyan-300 transition-colors"
                >
                  <span>Read Cookie Policy</span>
                  <FileText className="w-4 h-4" />
                </a>
              </div>

              <div className="bg-gray-900 p-4 rounded-lg">
                <h2 className="font-semibold mb-2">Community Guidelines</h2>
                <p className="text-gray-400 text-sm mb-4">
                  Our standards and expectations for community behavior.
                </p>
                <a
                  href="/guidelines"
                  target="_blank"
                  className="inline-flex items-center space-x-2 text-cyan-400 hover:text-cyan-300 transition-colors"
                >
                  <span>Read Community Guidelines</span>
                  <FileText className="w-4 h-4" />
                </a>
              </div>

              <div className="mt-8 text-center">
                <p className="text-sm text-gray-400">
                  Last updated: March 2025
                </p>
              </div>
            </div>
          )}
          {/* Other sections will be implemented similarly */}
        </div>
      )}
    </div>
  );
}

export default Settings;