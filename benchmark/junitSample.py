from junit_xml import TestSuite, TestCase
from junit_xml import to_xml_report_file

for srv in ['vm-01', 'vm-02']:
    globals()(f'test_cases_{srv}') = [
        TestCase(name='Test-mem', classname='test.mem', elapsed_sec=2, file=f'.\PerformanceTest\{srv}.json'),
        TestCase(name='Test-cpu', classname='test.cpu', elapsed_sec=4, file=f'.\PerformanceTest\{srv}.json'),
        TestCase(name='Test-io', classname='test.io', elapsed_sec=6, file=f'.\PerformanceTest\{srv}.json'),
        TestCase(name='Test-iperf', classname='test.iperf', elapsed_sec=8, file=f'.\PerformanceTest\{srv}.json')
        ]

    globals()(f'ts_{srv}) = TestSuite("Performance Benchmarking on vm-01", test_cases_vm_01)
    ts_vm_01.hostname = 'vm-01'

test_cases_vm_02 = [
    TestCase(name='Test-mem', classname='test.mem', elapsed_sec=1, file=".\PerformanceTest\vm-02.json"),
    TestCase(name='Test-cpu', classname='test.cpu', elapsed_sec=2, file=".\PerformanceTest\vm-02.json"),
    TestCase(name='Test-io', classname='test.io', elapsed_sec=3, file=".\PerformanceTest\vm-02.json"),
    TestCase(name='Test-iperf', classname='test.iperf', elapsed_sec=4, file=".\PerformanceTest\vm-02.json")
    ]

ts_vm_02 = TestSuite("Performance Benchmarking on vm-02", test_cases_vm_02)
ts_vm_02.hostname = 'vm-02'

# pretty printing is on by default but can be disabled using prettyprint=False
print(TestSuite.to_xml_string([ts_vm_01, ts_vm_02]))

# you can also write the XML to a file and not pretty print it
with open('output.xml', 'w') as f:
    to_xml_report_file(f, [ts_vm_01, ts_vm_02], prettyprint=False, encoding='utf-8')