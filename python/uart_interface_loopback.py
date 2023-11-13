import sys
import time
import serial
import glob
from typing import List

#######################

DEFAULT_PORT= None
DEFAULT_BAUDRATE = 115200

#######################

TITLE = """
  _____ _     _____ ____      _   _       _  _    ___   ___  
 | ____| |   | ____/ ___|    | | | |     | || |  / _ \ / _ \ 
 |  _| | |   |  _|| |   _____| |_| |_____| || |_| | | | (_) |
 | |___| |___| |__| |__|_____|  _  |_____|__   _| |_| |\__, |
 |_____|_____|_____\____|    |_| |_|        |_|  \___/   /_/
         _   ___ ___   ___          _        _   
        /_\ | __/ __| | _ \_ _ ___ (_)___ __| |_ 
       / _ \| _|\__ \ |  _/ '_/ _ \| / -_) _|  _|
      /_/ \_\___|___/ |_| |_| \___// \___\__|\__|
                                 |__/           
"""

def serial_ports() -> List[str]:
    """ Lists serial port names

        :raises EnvironmentError:
            On unsupported or unknown platforms
        :returns:
            A list of the serial ports available on the system
    """
    if sys.platform.startswith('win'):
        ports = ['COM%s' % (i + 1) for i in range(256)]
    elif sys.platform.startswith('linux') or sys.platform.startswith('cygwin'):
        # this excludes your current terminal "/dev/tty"
        ports = glob.glob('/dev/tty[A-Za-z]*')
    elif sys.platform.startswith('darwin'):
        ports = glob.glob('/dev/tty.*')
    else:
        raise EnvironmentError('Unsupported platform')

    result = []
    for port in ports:
        try:
            s = serial.Serial(port)
            s.close()
            result.append(port)
        except (OSError, serial.SerialException):
            pass
    return result

def serial_port_menu() -> str:
    available_ports = serial_ports()
    
    while len(available_ports) == 0:
        input("No serial port available. Make sure to connect to device then press enter to try again")
        available_ports = serial_ports()
    if len(available_ports) == 1:
        port = available_ports[0]
        print(f'Using only available port "{port}"')
        return port
    while True:
        print("Choose a serial port:")
        for i, port in enumerate(available_ports):
            print(f"    ({i}) {port}")
        try:
            resp = int(input(""))
        except ValueError:
            print("Wrong reponse type, try again !")
        else:
            try:
                port = available_ports[resp]
                return port
            except IndexError:
                print(f"{resp} is out of range, try again !")
                
def baudrate_menu() -> int:
    while True:
        print("Choose a baudrate:")
        try:
            resp = int(input(""))
        except ValueError:
            print("Wrong reponse type, try again !")
        else:
            return resp

def main(input_bytes: bytes) -> bytes:
    print(TITLE)

    if DEFAULT_PORT:
        if DEFAULT_PORT in serial_ports():
            print(f"Using default serial port: {DEFAULT_PORT}")
            port = DEFAULT_PORT
        else:
            print(f"Default serial port is not available.")
            port = serial_port_menu()
    else:
        print(f"Default serial port is not set.")
        port = serial_port_menu()
    if DEFAULT_BAUDRATE:
        print(f"Using default baudrate: {DEFAULT_BAUDRATE}")
        baudrate = DEFAULT_BAUDRATE
    else:
        print(f"Default baudrate is not set.")
        baudrate = baudrate_menu()
    print("")
    print(f"Sending input data: \t{input_bytes.hex()}")
    print("")
    with serial.Serial(port, baudrate) as ser:
        ser.write(input_bytes)
        output_bytes = ser.read(size=16)

    return output_bytes

if __name__ == "__main__":

    input_data = "000102030405060708090a0b0c0d0e0f"          #16 bytes, hexadecimal form
    
    try:
        if len(input_data) != 32:
            print(f'"input_data" length is not 16 bytes')
            exit() 
        input_bytes = bytes.fromhex(input_data)
    except ValueError:
        print(f'"input_data" value is not a correct hexadecimal form')
        exit()  
    output_bytes = main(input_bytes)
    print(f"Received data: \t\t{output_bytes.hex()}")
    print("\nLoopback test status: \t",end="")
    if (input_data == output_bytes.hex()):
        print("SUCCES")
    else:
        print("FAIL")
        
        