import time

try:
    while True:
        print("The script is running... Press Ctrl+C to stop.")
        time.sleep(5)  # Wait for 5 seconds before printing again
except KeyboardInterrupt:
    print("Script stopped by the user.")

