#!/usr/bin/env ruby
# Simple Big Internet Button Demo

require 'serialport'

port = '/dev/ttyACM0'
serial = SerialPort.new(port, 9600, 8, 1, SerialPort::NONE)
sleep(2)

puts "Big Internet Button Demo - Connected!"
puts "Running light and sound show..."

# Fun pattern
5.times do |i|
  puts "Cycle #{i+1}/5"
  
  serial.write('2')  # LED ON
  sleep(0.3)
  serial.write('3')  # High beep
  sleep(0.2)
  serial.write('1')  # LED OFF
  sleep(0.2)
  serial.write('4')  # Low beep
  sleep(0.5)
end

# Grand finale
puts "Grand finale!"
3.times do
  serial.write('2')  # LED ON
  serial.write('3')  # High beep
  sleep(0.1)
  serial.write('1')  # LED OFF
  sleep(0.1)
end

serial.write('2')  # Leave LED ON
sleep(1)
serial.write('1')  # LED OFF

puts "Demo complete!"
puts "\nThe physical button sends 'Enter' key when pressed."
puts "Try pressing it with a text editor open!"

serial.close