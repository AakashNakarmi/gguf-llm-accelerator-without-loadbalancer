from datetime import datetime
from zoneinfo import ZoneInfo

import pytz
import logging

class TimeFormatter(logging.Formatter):
    def formatTime(self, record, datefmt=None):
        converter = datetime.fromtimestamp(record.created, tz=pytz.timezone('Asia/Qatar'))
        return converter.strftime('%Y-%m-%d %H:%M:%S %z')
    
def get_logger():
    """
    Creates and returns a logger with a custom time formatter.

    Args:
        name (str): The name of the logger.
        timezone (str): The timezone for the log timestamps (default is 'Asia/Qatar').

    Returns:
        logging.Logger: Configured logger instance.
    """
    
    # Create a formatter with the custom time formatter
    formatter = TimeFormatter("%(asctime)s - %(levelname)s - %(message)s")
    logging.basicConfig(level=logging.INFO)
    logging.getLogger().handlers[0].setFormatter(formatter)
    logger = logging.getLogger(__name__)

    return logger

