import json

import eHive


class BaseProdRunnable(eHive.BaseRunnable):
    def flow_output_data(self, data: dict, channel: int = 1) -> None:
        self.dataflow({
            'data': json.dumps(data)
        }, channel)

    def get_input_data(self) -> dict:
        return json.loads(self.param("data"))

    def write_result(self, output: dict) -> None:
        self.dataflow({
            'job_id': self.input_job.dbID,
            'output': json.dumps(output)
        }, 2)

    def write_progress(self, message: dict) -> None:
        self.dataflow({
            'job_id': self.input_job.dbID,
            'message': json.dumps(message)
        }, 3)