/*
 * Copyright 2006-2011 The FLWOR Foundation.
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 * http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#include <string.h>
#include "stream_wrapper.h"
namespace zorba {
unsigned int utf8_sequence_length(const char* lead_it);
namespace csv {

StreamWrapper::StreamWrapper(Item string_item, unsigned int temp_buf_size)
  : theStringItem(string_item)
{
  //this->string_item = string_item;
	csv_is = &string_item.getStream();
  if(temp_buf_size < 4096)
    temp_buf_size = 4096;
  this->temp_buf_size = temp_buf_size;

  tempstr = new char[temp_buf_size + 10];
  start_str = tempstr;
  end_str = start_str;
  utf8_len = 0;
}

StreamWrapper::~StreamWrapper()
{
  delete[] tempstr;
}

void StreamWrapper::read_buf()
{
  if(start_str != end_str)
  {
    memmove(tempstr, start_str, (end_str-start_str));
  }
  end_str = tempstr +  (end_str-start_str);
  start_str = tempstr;
  std::streambuf  *csv_buf = csv_is->rdbuf();
  std::streamsize  readlen = csv_buf->sgetn(end_str, temp_buf_size - (end_str-start_str));
  if (readlen != (temp_buf_size - (end_str-start_str)))
    csv_is->setstate(std::ios_base::eofbit | std::ios_base::failbit);	// short read
  end_str += readlen;

}

bool StreamWrapper::is_end()
{
  return csv_is->eof() && (start_str == end_str);
}

unsigned int StreamWrapper::get_utf8_sequence_length()
{
  if(start_str == end_str)
  {
    read_buf();
  }
  utf8_len = utf8_sequence_length(start_str);
  return utf8_len;
}

const char *StreamWrapper::get_utf8_seq()
{
  if(!utf8_len)
    utf8_len = get_utf8_sequence_length();
  if((start_str+utf8_len) > end_str)
  {
    read_buf();
  }
  return start_str;
}

bool StreamWrapper::compare(std::string &other)
{
  int other_length = (int)other.length();
  if((end_str-start_str) < other_length)
  {
    read_buf();
  }
  if((end_str-start_str) < other_length)
  {
    return false;
  }
  if(other_length == 1)
  {
    return (start_str[0] == other.c_str()[0]);
  }
  if(!strncmp(other.c_str(), start_str, other_length))
    return true;
  else
    return false;
}

void StreamWrapper::skip(unsigned int nr_chars)
{
  utf8_len = 0;
  if((int)nr_chars > (end_str-start_str))
  {
    nr_chars -= (end_str-start_str);
    start_str = end_str;
    read_buf();
  }
  if((int)nr_chars >= (end_str-start_str))
  {
    end_str = tempstr;
    start_str = tempstr;
  }
  else
  {
    start_str += nr_chars;
  }
}

bool StreamWrapper::reset()
{
  std::streamoff pos = csv_is->tellg();
  if(pos == 0)
    return true;
  csv_is->seekg(0);
  if(csv_is->fail())
  {
    csv_is->clear();
    return false;
  }
  start_str = tempstr;
  end_str = start_str;
  utf8_len = 0;
  return true;
}




/////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////
CharPtrStream::CharPtrStream(Item string_item)
{
  this->string_item = string_item;
  csv_string = string_item.getStringValue();
  str = csv_string.c_str();
}

CharPtrStream::~CharPtrStream()
{
}
  
bool CharPtrStream::is_end()
{
  return !*str;
}

unsigned int CharPtrStream::get_utf8_sequence_length()
{
  return  utf8_sequence_length(str);
}

const char *CharPtrStream::get_utf8_seq()
{
  return str;
}

bool CharPtrStream::compare(std::string &other)
{
  return !strncmp(other.c_str(), str, other.length());
}

void CharPtrStream::skip(unsigned int nr_chars)
{
  str += nr_chars;
}

bool CharPtrStream::reset()
{
  str = csv_string.c_str();
  return true;
}


}}//end namespace csv/zorba