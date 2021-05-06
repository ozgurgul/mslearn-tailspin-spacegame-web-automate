from junit_xml import TestSuite, TestCase
from junit_xml import to_xml_report_file

def add_test_cases(server):
    
    test_cases = [
        TestCase(name='Test-mem', classname='test.mem', elapsed_sec=2, file=f'.\PerformanceTest\{server}.json'),
        TestCase(name='Test-cpu', classname='test.cpu', elapsed_sec=4, file=f'.\PerformanceTest\{server}.json'),
        TestCase(name='Test-io', classname='test.io', elapsed_sec=6, file=f'.\PerformanceTest\{server}.json'),
        TestCase(name='Test-iperf', classname='test.iperf', elapsed_sec=8, file=f'.\PerformanceTest\{server}.json')
    ]

    ts = TestSuite(f"Performance Benchmarking on {server}", test_cases)
    ts.hostname = f'{server}'
    return ts

# pretty printing is on by default but can be disabled using prettyprint=False
ts=[add_test_cases('vm_01'), add_test_cases('vm_02')]
print(TestSuite.to_xml_string(ts))

# you can also write the XML to a file and not pretty print it
with open('output.xml', 'w') as f:
    to_xml_report_file(f, ts, prettyprint=False, encoding='utf-8')