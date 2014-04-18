require 'ecdsa'
require 'digest'

Base58Chars = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'.split('')

def base58_decode(string)
  string.each_char.reduce(0) do |result, char|
    result * 58 + Base58Chars.index(char)
  end
end

def base58_encode(number)
  result = ''
  while number > 0
    number, remainder = number.divmod 58
    result += Base58Chars[remainder]
  end
  result.reverse
end

def base58_encode_binary(data)
  leading_zero_count = data.match(/\A(\0*)/)[1].size
  '1' * leading_zero_count + base58_encode(ECDSA::Format::IntegerOctetString.decode data)
end

def base58check_checksum(data)
  Digest::SHA256.digest(Digest::SHA256.digest(data))[0, 4]
end

def base58check_decode(string)
  bignum = base58_decode string  
  str = ECDSA::Format::IntegerOctetString.encode(bignum, 38)
  version = str[0]
  payload = str[1, str.size - 5]
  if version.ord != 0x80
    raise "This doesn't look like a private key; version byte is %#x." % version.ord
  end
  checksum = base58check_checksum version + payload
  raise "Invalid checksum; data might be corrupt." if str[-4, 4] != checksum
  payload
end

def base58check_encode(version, payload)
  checksum = base58check_checksum version + payload
  base58_encode_binary version + payload + checksum
end

def private_key_decode(string)
  data = base58check_decode string
  data.force_encoding('binary')
  data = data[0, data.size - 1]  # remove trailing "\x01" byte, not sure why it is there
  raise "Expected private key to be 32 bytes." if data.size != 32
  ECDSA::Format::IntegerOctetString.decode(data)
end

def bitcoin_address(public_key, compression)
  string = ECDSA::Format::PointOctetString.encode(public_key, compression: compression)
  hash = Digest::RMD160.digest Digest::SHA256.digest string
  base58check_encode("\x00", hash)
end

# Print out the bitcoin address corresponding to this private key, assuming that
# the *compressed* version of the public key was used to make the address.
def inspect_private_key(private_key)
  public_key = ECDSA::Group::Secp256k1.generator.multiply_by_scalar private_key
  puts bitcoin_address public_key, true
end