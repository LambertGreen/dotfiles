# -----------------------------------------------------------------------------
#
# This file is the copyrighted property of Tableau Software and is protected
# by registered patents and other applicable U.S. and international laws and
# regulations.
#
# Unlicensed use of the contents of this file is prohibited. Please refer to
# the NOTICES.txt file for further details.
#
# -----------------------------------------------------------------------------
import sys
import struct
import gdb.printing

class QStringPrinter:
    """Print summary for QString object"""
    def __init__(self, val):
        self.val = val

    def to_string(self):
        s = '"'
        dataPtr = self.val['d']
        data = dataPtr.reinterpret_cast(gdb.lookup_type('char').pointer()) + dataPtr['offset']
        dataSize = dataPtr['size'] * gdb.lookup_type('unsigned short').sizeof
        dataSize = min(500, dataSize)
        return data.decode('UTF-8')[:dataSize]

    def display_hint(self):
        return 'string'

class TStringManagerPrinter:
    """Print TStringManager summary"""

    def __init__(self, val):
        self.val = val

    def to_string(self):
        stringMode = self.val['m_mode']
        # assume "short" string, mode == length of the text in TChars (not counting the terminating null)
        stringLength = stringMode
        capacity = stringLength
        # stringPtr will be the pointer to the actual chars
        stringPtr = self.val['m_shortString'].address

        if stringMode == -1:
            # string is in long mode actually
            header = self.val['m_pLongStringHeader'].dereference()
            headerPtr = header.address
            # headerPtr + offset of TLongStringHeader.m_length
            try:
                stringLength = header['m_length']
                capacity = header['m_capacity']
            except gdb.error as exc:
                gdb.write('<errorfail : %i + %i> : %s\n' % (headerPtr, 8, exc.message), gdb.STDLOG)
                raise gdb.MemoryError
            # headerPtr + sizeof(TLongStringHeader)
            stringPtr = headerPtr + 1
        else:
            if stringMode < 0 or stringMode >= 16:
                gdb.write('<errorfail: m_mode = %i>\n' % (stringMode), gdb.STDLOG)
                raise gdb.error
        stringLength = min(500, stringLength)
        gdb.write('<StringLength> : %i\n' % (stringLength), gdb.STDLOG)
        gdb.write('<Capacity> : %i\n' % (capacity), gdb.STDLOG)
        data = bytearray(gdb.selected_inferior().read_memory(stringPtr, 2*stringLength))
        return data.decode('UTF-16')

class TStringCorePrinter:
    """Print TStringCode summary"""

    def __init__(self, val):
        self.val = val

    def to_string(self):
        mgr = self.val['m_mgr']
        return TStringManagerPrinter(mgr).to_string()

    def display_hint(self):
        return 'string'

_map_capping_size = 255


class LibcxxHashTable_Printer:
    def __init__(self, val):
        self.val = val
        self.num_elements = None
        self.next_element = None
        self.bucket_count = None

    def update(self):
        self.num_elements = None
        self.next_element = None
        self.bucket_count = None
        try:
            # unordered_map is made up a a hash_map, which has 4 pieces in it:
            #   bucket list :
            #      array of buckets
            #   p1 (pair):
            #      first - pointer to first loaded element
            #   p2 (pair):
            #      first - number of elements
            #      second - hash function
            #   p3 (pair):
            #      first - max_load_factor
            #      second - equality operator function
            #
            # For display, we actually dont need to go inside the buckets, since 'p1' has a way to iterate over all
            # the elements directly.
            #
            # We will calculate other values about the map because they will be useful for the summary.
            #
            table = self.val['__table_']

            bl_ptr = table['__bucket_list_']['__ptr_']
            self.bucket_array_ptr = bl_ptr['__first_']
            self.bucket_count = bl_ptr['__second_']['__data_']['__first_']

            self.begin_ptr = table['__p1_']['__first_']['__next_']

            self.num_elements = table['__p2_']['__first_']
            self.max_load_factor = table['__p3_']['__first_']

            # save the pointers as we get them
            #   -- dont access this first element if num_element==0!
            self.elements_cache = []
            if self.num_elements:
                self.next_element = self.begin_ptr
            else:
                self.next_element = None
        except Exception as e:
            pass

    def num_children(self):
        global _map_capping_size
        num_elements = self.num_elements
        if num_elements is not None:
            if num_elements > _map_capping_size:
                num_elements = _map_capping_size
        return num_elements

    def has_children(self):
        return True

    def get_child_index(self, name):
        try:
            return int(name.lstrip('[').rstrip(']'))
        except:
            return -1

    def get_child_at_index(self, index):
        if index < 0:
            return None
        if index >= self.num_children():
            return None

        # extend
        while index >= len(self.elements_cache):
            # if we hit the end before we get the index, give up:
            if not self.next_element:
                return None

            node = self.next_element.Dereference()

            value = node['__value_']
            hash_value = node['__hash_']
            self.elements_cache.append((value, hash_value))

            self.next_element = node['__next_']
            if not self.next_element.GetValueAsUnsigned(0):
                self.next_element = None

        # hit the index! so we have the value
        value, hash_value = self.elements_cache[index]
        return '[%d] <hash %d>' % (index, hash_value), value.GetData(), value.GetType()

def build_pretty_printer():
    """Builds the pretty printer for Tableau"""
    pp = gdb.printing.RegexpCollectionPrettyPrinter("Tableau")
    pp.add_printer('TStringCore', '^TStringCore$', TStringCorePrinter)
    pp.add_printer('TStringManager', '^TStringManager$',TStringManagerPrinter)
    pp.add_printer('QString', '^QString$', QStringPrinter)
    pp.add_printer('unordered_map','^(std::__1::)unordered_(multi)?(map|set)<.+> >$', LibcxxHashTable_Printer)
    return pp


def register_printers():
    """Register all known Tableau printers"""
    gdb.printing.register_pretty_printer(gdb.current_objfile(), build_pretty_printer())
