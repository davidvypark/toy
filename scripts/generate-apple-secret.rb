#!/usr/bin/env ruby
# Generate Apple Sign-In client secret JWT for Supabase
#
# Usage: ruby generate-apple-secret.rb
#
# Required gems: jwt
# Install with: gem install jwt

require 'jwt'
require 'time'

# === FILL IN YOUR VALUES ===
TEAM_ID = 'ZH8H29HA3J'           # Your Apple Developer Team ID (10 characters)
KEY_ID = 'Y44W2T6VA6'             # The Key ID from Apple Developer Portal
CLIENT_ID = 'com.kindauseful.TOY.auth'      # Your Service ID (e.g., com.kindauseful.TOY.auth)
KEY_FILE = '~/Downloads/AuthKey_Y44W2T6VA6.p8'      # Path to your .p8 file
# ===========================

# Read the private key (expand ~ to home directory)
private_key = OpenSSL::PKey::EC.new(File.read(File.expand_path(KEY_FILE)))

# JWT headers
headers = {
  'alg' => 'ES256',
  'kid' => KEY_ID
}

# JWT claims
claims = {
  'iss' => TEAM_ID,
  'iat' => Time.now.to_i,
  'exp' => Time.now.to_i + 86400 * 180, # 180 days (max allowed)
  'aud' => 'https://appleid.apple.com',
  'sub' => CLIENT_ID
}

# Generate the JWT
token = JWT.encode(claims, private_key, 'ES256', headers)

puts "Your Apple Client Secret JWT:"
puts "-" * 50
puts token
puts "-" * 50
puts "\nThis token is valid for 180 days."
puts "Paste this into Supabase Dashboard → Authentication → Apple → Secret Key"
