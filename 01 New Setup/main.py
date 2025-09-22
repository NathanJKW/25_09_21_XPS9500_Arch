#!/usr/bin/env python3
from utils.sudo_session import start_sudo_session
#import tasks  # our other module

def say_hello():
    """Normal user work"""
    print("👋 Hello, I’m a normal user method.")

def update_system(run):
    """Needs sudo"""
    print("🔧 Updating system packages...")
    run(["pacman", "-Syu", "--noconfirm"])

if __name__ == "__main__":
    run, close = start_sudo_session()
    try:
        say_hello()            # normal user work
        update_system(run)     # sudo work in main script
        # tasks.install_git(run) # sudo work in another module
    finally:
        close()
