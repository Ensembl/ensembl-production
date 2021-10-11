"""
.. See the NOTICE file distributed with this work for additional information
   regarding copyright ownership.
   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at
       http://www.apache.org/licenses/LICENSE-2.0
   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
"""
from watchdog.observers import Observer
from watchdog.events import PatternMatchingEventHandler
import time
import os 
import eHive

class WatchDirectory(PatternMatchingEventHandler):
    def __init__(self, file_name, observer, event_triggered):
        self.observer = observer
        self.event_triggered = event_triggered
        super(WatchDirectory, self).__init__(
            patterns=[file_name],
            case_sensitive=False,
        )
    def on_any_event(self, event):
        self.observer.stop()
        self.event_triggered = True

class Monitor:
    def __init__(self):
        self.observer = Observer()
        self.event_triggered = False

    def watch(self, directory_name, file_name, watch_until_hours=48):
        watch_event = WatchDirectory(file_name, self.observer, self.event_triggered)
        self.observer.schedule(watch_event, directory_name, recursive=True)
        self.observer.start()
        now = time.time()
        watch_until = now + (watch_until_hours * 60 * 60)
        try:
            while self.observer.is_alive() and time.time() <= watch_until :
                time.sleep(1)

            if not self.observer.is_alive() and watch_event.event_triggered:
                self.observer.join()
                return True
        except:
            self.observer.stop()

        self.observer.stop() 
        self.observer.join()
        return False


class FileWatcher(eHive.BaseRunnable):
    """ Trigger the event based on file creation in the watched directory  """
    
    def write_output(self):
        directory = self.param('directory')
        file_name = self.param('file_name')
        watch_until = self.param_required('watch_until')
        wait = self.param_required('wait')
        
        if wait :
            file_status = self.wait_for_file(directory, file_name, watch_until)
            if not file_status:
                raise Exception(f"No event observed in directory : {directory} before timeout")


    def wait_for_file(self, directory, file_name, watch_until):
        if not file_name:
            file_name = '*'
        watch_dir = Monitor()
        event_found=watch_dir.watch(directory, file_name, watch_until)
        return  event_found

    def run(self):
        pass

