#!/usr/bin/python3
import sys
import os
from datetime import datetime   
from junit_xml import TestSuite, TestCase
from junit_xml import to_xml_report_file

def add_test_cases(server):
    
    test_cases = [
        TestCase(name='Test-cpu', classname='test.cpu', elapsed_sec=1, file=f'.\PerformanceTest\Perf_Bench_{server}.json'),
        TestCase(name='Test-mem', classname='test.mem', elapsed_sec=1, file=f'.\PerformanceTest\Perf_Bench_{server}.json'),
        TestCase(name='Test-io', classname='test.io', elapsed_sec=1, file=f'.\PerformanceTest\Perf_Bench_{server}.json'),
        TestCase(name='Test-iperf', classname='test.iperf', elapsed_sec=1, file=f'.\PerformanceTest\Perf_Bench_{server}.json')
    ]

    ts = TestSuite(f"Performance Benchmarking on {server}", test_cases)
    ts.hostname = f'{server}'
    return ts


def main(argv):
        
    # pretty printing is on by default but can be disabled using prettyprint=False
    ts = map(add_test_cases, argv)
    to_file_str = TestSuite.to_xml_string(ts)

    # Get the current time
    utc_datetime = datetime.utcnow()
    time_str = utc_datetime.strftime("%Y%m%d_%H%M%S")
    
    # you can also write the XML to a file and not pretty print it
    with open('./PerformanceTest/' + 'TEST-{date}.xml'.format(date=time_str), 'w') as f:
        f.write(to_file_str)

    
if __name__ == "__main__":
    print(f'List Length:{len(sys.argv)}' )
    print(f'Argument List:{str(sys.argv)}' )

    # Avoid the first item in the list
    main(sys.argv[1:])