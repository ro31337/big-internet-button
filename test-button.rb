#!/usr/bin/env ruby
# Big Internet Button Test Script
# Tests serial communication and LED/sound control

require 'serialport'
require 'io/console'

class BigInternetButton
  def initialize(port = '/dev/ttyACM0', baud_rate = 9600)
    @port = port
    @baud_rate = baud_rate
    puts "Connecting to Big Internet Button on #{@port} at #{@baud_rate} baud..."
    
    begin
      @serial = SerialPort.new(@port, @baud_rate, 8, 1, SerialPort::NONE)
      sleep(2) # Wait for connection to establish
      puts "Connected! Running tests...\n\n"
    rescue => e
      puts "Error: Could not open serial port #{@port}"
      puts "Details: #{e.message}"
      puts "\nTroubleshooting:"
      puts "1. Check if the device is at /dev/ttyACM0"
      puts "2. You may need to add your user to the dialout group:"
      puts "   sudo usermod -a -G dialout $USER"
      puts "   Then log out and back in"
      puts "3. Install serialport gem if not installed:"
      puts "   gem install serialport"
      exit(1)
    end
  end
  
  def led_on
    puts "Turning LED ON..."
    @serial.write('2')
  end
  
  def led_off
    puts "Turning LED OFF..."
    @serial.write('1')
  end
  
  def beep_high_f
    puts "Playing High F beep (100ms)..."
    @serial.write('3')
  end
  
  def beep_middle_g_sharp
    puts "Playing Middle G# beep (100ms)..."
    @serial.write('4')
  end
  
  def run_tests
    puts "1. LED ON test"
    led_on
    sleep(1)
    
    puts "\n2. High F beep test"
    beep_high_f
    sleep(1)
    
    puts "\n3. Middle G# beep test"
    beep_middle_g_sharp
    sleep(1)
    
    puts "\n4. LED OFF test"
    led_off
    sleep(1)
    
    puts "\n5. Running pattern: Flash + Beeps..."
    3.times do |i|
      print "  Pattern #{i + 1}..."
      led_on
      sleep(0.2)
      beep_high_f
      sleep(0.2)
      led_off
      sleep(0.2)
      beep_middle_g_sharp
      puts " done"
      sleep(0.5)
    end
    
    puts "\nTest complete!"
  end
  
  def interactive_mode
    puts "\n" + "="*50
    puts "INTERACTIVE MODE"
    puts "="*50
    puts "Commands:"
    puts "  1 - LED OFF"
    puts "  2 - LED ON"
    puts "  3 - High F beep"
    puts "  4 - Middle G# beep"
    puts "  p - Run pattern"
    puts "  q - Quit"
    puts "\nNOTE: The physical button sends 'Enter' key when pressed"
    puts "(Open a text editor to test the Enter key functionality)"
    puts "="*50
    
    loop do
      print "\nCommand: "
      input = STDIN.getch
      puts input  # Echo the character
      
      case input
      when '1'
        led_off
      when '2'
        led_on
      when '3'
        beep_high_f
      when '4'
        beep_middle_g_sharp
      when 'p', 'P'
        puts "Running pattern..."
        led_on; sleep(0.1)
        beep_high_f; sleep(0.1)
        led_off; sleep(0.1)
        beep_middle_g_sharp
      when 'q', 'Q'
        puts "Exiting..."
        break
      when "\u0003"  # Ctrl+C
        puts "\nExiting..."
        break
      else
        puts "Unknown command: '#{input}'"
      end
    end
  end
  
  def close
    @serial.close if @serial && !@serial.closed?
    puts "Serial connection closed."
  end
end

# Check if serialport gem is installed
begin
  require 'serialport'
rescue LoadError
  puts "The 'serialport' gem is not installed."
  puts "Installing it now..."
  system("gem install serialport")
  
  # Try to require again
  begin
    require 'serialport'
  rescue LoadError
    puts "Failed to install serialport gem."
    puts "Please install it manually: gem install serialport"
    exit(1)
  end
end

# Main execution
if __FILE__ == $0
  button = BigInternetButton.new
  
  begin
    button.run_tests
    button.interactive_mode
  rescue Interrupt
    puts "\n\nInterrupted by user"
  ensure
    button.close
  end
end