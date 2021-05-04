from junit_xml import TestSuite, TestCase
from junit_xml import to_xml_report_file

test_cases = [
    TestCase(name='Test1-mem', classname='some.class.mem', elapsed_sec=123.345, stdout='I am stdout for mem!', stderr='I am stderr for mem!', file='.\PerformanceTest\dummy.json'),
    TestCase(name='Test1-cpu', classname='some.class.cpu', elapsed_sec=23.345, stdout='I am stdout for cpu!', stderr='I am stderr for cpu!', file='.\PerformanceTest\dummy.json'),
    TestCase(name='Test1-io', classname='some.class.io', elapsed_sec=3.345, stdout='I am stdout for io!', stderr='I am stderr for io!', file='.\PerformanceTest\dummy.json'),
    TestCase(name='Test1-iperf', classname='some.class.iperf', elapsed_sec=3.5, stdout='I am stdout for iperf!', stderr='I am stderr for iperf!', file='.\PerformanceTest\dummy.json')
    ]

ts = TestSuite("my test suite", test_cases)

ts.hostname = 'vm-01'

# pretty printing is on by default but can be disabled using prettyprint=False
print(TestSuite.to_xml_string([ts]))

# you can also write the XML to a file and not pretty print it
with open('output.xml', 'w') as f:
    to_xml_report_file(f, [ts], prettyprint=False, encoding='utf-8')