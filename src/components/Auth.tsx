import React, { useState, useEffect } from 'react';
import { signIn, signUp, checkUsernameAvailability } from '../lib/auth';
import { Building2, Mail, Lock, User, AtSign, MapPin, Globe, Briefcase, Phone } from 'lucide-react';

type AuthMode = 'signin' | 'signup';

export function Auth() {
  const [mode, setMode] = useState<AuthMode>('signin');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Common fields
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [accountType, setAccountType] = useState<'personal' | 'business'>('personal');

  // Personal account fields
  const [username, setUsername] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [location, setLocation] = useState('');
  const [website, setWebsite] = useState('');
  const [bio, setBio] = useState('');

  // Business account fields
  const [businessUsername, setBusinessUsername] = useState('');
  const [businessName, setBusinessName] = useState('');
  const [businessLocation, setBusinessLocation] = useState('');
  const [businessWebsite, setBusinessWebsite] = useState('');
  const [businessBio, setBusinessBio] = useState('');
  const [industry, setIndustry] = useState('');
  const [businessPhone, setBusinessPhone] = useState('');

  // Username availability states
  const [usernameAvailable, setUsernameAvailable] = useState<boolean | null>(null);
  const [checkingUsername, setCheckingUsername] = useState(false);

  useEffect(() => {
    const checkUsername = async () => {
      if (!username && !businessUsername) {
        setUsernameAvailable(null);
        return;
      }

      const currentUsername = accountType === 'personal' ? username : businessUsername;
      if (currentUsername.length < 3) {
        setUsernameAvailable(null);
        return;
      }

      setCheckingUsername(true);
      const { available } = await checkUsernameAvailability(currentUsername);
      setUsernameAvailable(available);
      setCheckingUsername(false);
    };

    const timeoutId = setTimeout(checkUsername, 500);
    return () => clearTimeout(timeoutId);
  }, [username, businessUsername, accountType]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      if (mode === 'signup') {
        const currentUsername = accountType === 'personal' ? username : businessUsername;
        
        const { available, error: usernameError } = await checkUsernameAvailability(currentUsername);
        if (!available) {
          setError(usernameError || 'Username is not available');
          setLoading(false);
          return;
        }

        const signupData = {
          email,
          password,
          username: currentUsername,
          displayName: accountType === 'personal' ? displayName : businessName,
          accountType,
          location: accountType === 'personal' ? location : businessLocation,
          website: accountType === 'personal' ? website : businessWebsite,
          bio: accountType === 'personal' ? bio : businessBio,
          ...(accountType === 'business' && {
            industry,
            phone: businessPhone,
          }),
        };
        const { error } = await signUp(signupData);
        if (error) throw error;
      } else {
        const { error } = await signIn(email, password);
        if (error) throw error;
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  const renderUsernameInput = (isPersonal: boolean) => {
    const value = isPersonal ? username : businessUsername;
    const setValue = isPersonal ? setUsername : setBusinessUsername;
    const showStatus = mode === 'signup' && value.length >= 3;

    return (
      <div>
        <label htmlFor={isPersonal ? "username" : "businessUsername"} className="sr-only">
          {isPersonal ? "Username" : "Business Username"}
        </label>
        <div className="relative">
          <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <AtSign className="h-5 w-5 text-gray-400" />
          </div>
          <input
            id={isPersonal ? "username" : "businessUsername"}
            name={isPersonal ? "username" : "businessUsername"}
            type="text"
            required
            value={value}
            onChange={(e) => setValue(e.target.value)}
            className={`appearance-none relative block w-full pl-10 pr-12 py-2 border ${
              showStatus
                ? usernameAvailable
                  ? 'border-green-500'
                  : 'border-red-500'
                : 'border-gray-700'
            } rounded-lg bg-gray-900 text-white placeholder-gray-400 focus:outline-none focus:ring-cyan-400 focus:border-cyan-400`}
            placeholder={isPersonal ? "Username" : "Business Username"}
          />
          {showStatus && (
            <div className="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none">
              {checkingUsername ? (
                <svg className="animate-spin h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
              ) : usernameAvailable ? (
                <span className="text-green-500">✓</span>
              ) : (
                <span className="text-red-500">×</span>
              )}
            </div>
          )}
        </div>
        {showStatus && !checkingUsername && !usernameAvailable && (
          <p className="mt-1 text-sm text-red-500">Username is already taken</p>
        )}
      </div>
    );
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-950 px-4">
      <div className="max-w-md w-full space-y-8">
        <div className="text-center">
          <h2 className="mt-6 text-3xl font-bold text-white">
            {mode === 'signin' ? 'Welcome back' : 'Create your account'}
          </h2>
          <p className="mt-2 text-sm text-gray-400">
            {mode === 'signin' ? (
              <>
                Don't have an account?{' '}
                <button
                  onClick={() => setMode('signup')}
                  className="text-cyan-400 hover:text-cyan-300"
                >
                  Sign up
                </button>
              </>
            ) : (
              <>
                Already have an account?{' '}
                <button
                  onClick={() => setMode('signin')}
                  className="text-cyan-400 hover:text-cyan-300"
                >
                  Sign in
                </button>
              </>
            )}
          </p>
        </div>

        <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
          {error && (
            <div className="bg-red-500/10 border border-red-500 text-red-500 rounded-lg p-4 text-sm">
              {error}
            </div>
          )}

          <div className="space-y-4 rounded-md">
            {mode === 'signup' && (
              <div className="space-y-2">
                <label className="text-sm font-medium text-gray-300">Account Type</label>
                <div className="grid grid-cols-2 gap-4">
                  <button
                    type="button"
                    onClick={() => setAccountType('personal')}
                    className={`p-4 rounded-lg flex flex-col items-center justify-center border ${
                      accountType === 'personal'
                        ? 'border-cyan-400 bg-cyan-400/10 text-cyan-400'
                        : 'border-gray-700 text-gray-400 hover:border-gray-600'
                    }`}
                  >
                    <User className="h-6 w-6 mb-2" />
                    <span className="text-sm font-medium">Personal</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setAccountType('business')}
                    className={`p-4 rounded-lg flex flex-col items-center justify-center border ${
                      accountType === 'business'
                        ? 'border-cyan-400 bg-cyan-400/10 text-cyan-400'
                        : 'border-gray-700 text-gray-400 hover:border-gray-600'
                    }`}
                  >
                    <Building2 className="h-6 w-6 mb-2" />
                    <span className="text-sm font-medium">Business</span>
                  </button>
                </div>
              </div>
            )}

            {mode === 'signin' ? (
              <div>
                <label htmlFor="identifier" className="sr-only">Email or Username</label>
                <div className="relative">
                  <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                    <Mail className="h-5 w-5 text-gray-400" />
                  </div>
                  <input
                    id="identifier"
                    name="identifier"
                    type="text"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    className="appearance-none relative block w-full pl-10 pr-3 py-2 border border-gray-700 rounded-lg bg-gray-900 text-white placeholder-gray-400 focus:outline-none focus:ring-cyan-400 focus:border-cyan-400"
                    placeholder="Email or Username"
                  />
                </div>
              </div>
            ) : (
              <>
                {renderUsernameInput(accountType === 'personal')}

                <div>
                  <label htmlFor="email" className="sr-only">Email</label>
                  <div className="relative">
                    <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <Mail className="h-5 w-5 text-gray-400" />
                    </div>
                    <input
                      id="email"
                      name="email"
                      type="email"
                      required
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      className="appearance-none relative block w-full pl-10 pr-3 py-2 border border-gray-700 rounded-lg bg-gray-900 text-white placeholder-gray-400 focus:outline-none focus:ring-cyan-400 focus:border-cyan-400"
                      placeholder="Email address"
                    />
                  </div>
                </div>

                {accountType === 'personal' ? (
                  <>
                    <div>
                      <label htmlFor="displayName" className="sr-only">Display Name</label>
                      <div className="relative">
                        <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                          <User className="h-5 w-5 text-gray-400" />
                        </div>
                        <input
                          id="displayName"
                          name="displayName"
                          type="text"
                          required
                          value={displayName}
                          onChange={(e) => setDisplayName(e.target.value)}
                          className="appearance-none relative block w-full pl-10 pr-3 py-2 border border-gray-700 rounded-lg bg-gray-900 text-white placeholder-gray-400 focus:outline-none focus:ring-cyan-400 focus:border-cyan-400"
                          placeholder="Display Name"
                        />
                      </div>
                    </div>

                    <div>
                      <label htmlFor="location" className="sr-only">Location</label>
                      <div className="relative">
                        <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                          <MapPin className="h-5 w-5 text-gray-400" />
                        </div>
                        <input
                          id="location"
                          name="location"
                          type="text"
                          value={location}
                          onChange={(e) => setLocation(e.target.value)}
                          className="appearance-none relative block w-full pl-10 pr-3 py-2 border border-gray-700 rounded-lg bg-gray-900 text-white placeholder-gray-400 focus:outline-none focus:ring-cyan-400 focus:border-cyan-400"
                          placeholder="Location (optional)"
                        />
                      </div>
                    </div>

                    <div>
                      <label htmlFor="website" className="sr-only">Website</label>
                      <div className="relative">
                        <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                          <Globe className="h-5 w-5 text-gray-400" />
                        </div>
                        <input
                          id="website"
                          name="website"
                          type="url"
                          value={website}
                          onChange={(e) => setWebsite(e.target.value)}
                          className="appearance-none relative block w-full pl-10 pr-3 py-2 border border-gray-700 rounded-lg bg-gray-900 text-white placeholder-gray-400 focus:outline-none focus:ring-cyan-400 focus:border-cyan-400"
                          placeholder="Website (optional)"
                        />
                      </div>
                    </div>

                    <div>
                      <label htmlFor="bio" className="sr-only">Bio</label>
                      <textarea
                        id="bio"
                        name="bio"
                        value={bio}
                        onChange={(e) => setBio(e.target.value)}
                        className="appearance-none relative block w-full p-3 border border-gray-700 rounded-lg bg-gray-900 text-white placeholder-gray-400 focus:outline-none focus:ring-cyan-400 focus:border-cyan-400"
                        placeholder="Bio (optional)"
                        rows={3}
                      />
                    </div>
                  </>
                ) : (
                  <>
                    <div>
                      <label htmlFor="businessName" className="sr-only">Business Name</label>
                      <div className="relative">
                        <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                          <Building2 className="h-5 w-5 text-gray-400" />
                        </div>
                        <input
                          id="businessName"
                          name="businessName"
                          type="text"
                          required
                          value={businessName}
                          onChange={(e) => setBusinessName(e.target.value)}
                          className="appearance-none relative block w-full pl-10 pr-3 py-2 border border-gray-700 rounded-lg bg-gray-900 text-white placeholder-gray-400 focus:outline-none focus:ring-cyan-400 focus:border-cyan-400"
                          placeholder="Business Name"
                        />
                      </div>
                    </div>

                    <div>
                      <label htmlFor="industry" className="sr-only">Industry</label>
                      <div className="relative">
                        <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                          <Briefcase className="h-5 w-5 text-gray-400" />
                        </div>
                        <input
                          id="industry"
                          name="industry"
                          type="text"
                          required
                          value={industry}
                          onChange={(e) => setIndustry(e.target.value)}
                          className="appearance-none relative block w-full pl-10 pr-3 py-2 border border-gray-700 rounded-lg bg-gray-900 text-white placeholder-gray-400 focus:outline-none focus:ring-cyan-400 focus:border-cyan-400"
                          placeholder="Industry"
                        />
                      </div>
                    </div>

                    <div>
                      <label htmlFor="businessLocation" className="sr-only">Business Location</label>
                      <div className="relative">
                        <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                          <MapPin className="h-5 w-5 text-gray-400" />
                        </div>
                        <input
                          id="businessLocation"
                          name="businessLocation"
                          type="text"
                          required
                          value={businessLocation}
                          onChange={(e) => setBusinessLocation(e.target.value)}
                          className="appearance-none relative block w-full pl-10 pr-3 py-2 border border-gray-700 rounded-lg bg-gray-900 text-white placeholder-gray-400 focus:outline-none focus:ring-cyan-400 focus:border-cyan-400"
                          placeholder="Business Location"
                        />
                      </div>
                    </div>

                    <div>
                      <label htmlFor="businessPhone" className="sr-only">Business Phone</label>
                      <div className="relative">
                        <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                          <Phone className="h-5 w-5 text-gray-400" />
                        </div>
                        <input
                          id="businessPhone"
                          name="businessPhone"
                          type="tel"
                          required
                          value={businessPhone}
                          onChange={(e) => setBusinessPhone(e.target.value)}
                          className="appearance-none relative block w-full pl-10 pr-3 py-2 border border-gray-700 rounded-lg bg-gray-900 text-white placeholder-gray-400 focus:outline-none focus:ring-cyan-400 focus:border-cyan-400"
                          placeholder="Business Phone"
                        />
                      </div>
                    </div>

                    <div>
                      <label htmlFor="businessWebsite" className="sr-only">Business Website</label>
                      <div className="relative">
                        <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                          <Globe className="h-5 w-5 text-gray-400" />
                        </div>
                        <input
                          id="businessWebsite"
                          name="businessWebsite"
                          type="url"
                          required
                          value={businessWebsite}
                          onChange={(e) => setBusinessWebsite(e.target.value)}
                          className="appearance-none relative block w-full pl-10 pr-3 py-2 border border-gray-700 rounded-lg bg-gray-900 text-white placeholder-gray-400 focus:outline-none focus:ring-cyan-400 focus:border-cyan-400"
                          placeholder="Business Website"
                        />
                      </div>
                    </div>

                    <div>
                      <label htmlFor="businessBio" className="sr-only">Business Description</label>
                      <textarea
                        id="businessBio"
                        name="businessBio"
                        value={businessBio}
                        onChange={(e) => setBusinessBio(e.target.value)}
                        className="appearance-none relative block w-full p-3 border border-gray-700 rounded-lg bg-gray-900 text-white placeholder-gray-400 focus:outline-none focus:ring-cyan-400 focus:border-cyan-400"
                        placeholder="Business Description"
                        rows={3}
                        required
                      />
                    </div>
                  </>
                )}
              </>
            )}

            <div>
              <label htmlFor="password" className="sr-only">Password</label>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <Lock className="h-5 w-5 text-gray-400" />
                </div>
                <input
                  id="password"
                  name="password"
                  type="password"
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="appearance-none relative block w-full pl-10 pr-3 py-2 border border-gray-700 rounded-lg bg-gray-900 text-white placeholder-gray-400 focus:outline-none focus:ring-cyan-400 focus:border-cyan-400"
                  placeholder="Password"
                />
              </div>
            </div>
          </div>

          <div>
            <button
              type="submit"
              disabled={loading}
              className="group relative w-full flex justify-center py-2 px-4 border border-transparent rounded-lg text-sm font-medium text-gray-900 bg-cyan-400 hover:bg-cyan-300 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-cyan-400 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? (
                <svg
                  className="animate-spin h-5 w-5 text-gray-900"
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                >
                  <circle
                    className="opacity-25"
                    cx="12"
                    cy="12"
                    r="10"
                    stroke="currentColor"
                    strokeWidth="4"
                  />
                  <path
                    className="opacity-75"
                    fill="currentColor"
                    d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                  />
                </svg>
              ) : mode === 'signin' ? (
                'Sign in'
              ) : (
                'Create account'
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}