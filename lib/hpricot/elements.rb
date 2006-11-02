module Hpricot
# Once you've matched a list of elements, you will often need to handle them as a group.  Or you
# may want to perform the same action on each of them.  Hpricot::Elements is an extension of Ruby's
# array class, with some methods added for altering elements contained in the array.
#
# If you need to create an element array from regular elements:
#
#   Hpricot::Elements[ele1, ele2, ele3]
#
# Assuming that ele1, ele2 and ele3 contain element objects (Hpricot::Elem, Hpricot::Doc, etc.)
#
# == Continuing Searches
#
# Usually the Hpricot::Elements you're working on comes from a search you've
# done.  Well, you can continue searching the list by using the same <tt>at</tt>
# and <tt>search</tt> methods you can use on plain elements.
#
#   elements = doc.search("/div/p")
#   elements = elements.search("/a[@href='http://hoodwink.d/']")
#   elements = elements.at("img")
#
# == Altering Elements
#
# When you're altering elements in the list, your changes will be reflected in
# the document you started searching from.
#
#   doc = Hpricot("That's my <b>spoon</b>, Tyler.")
#   doc.at("b").swap("<i>fork</i>")
#   doc.to_html
#     #=> "That's my <i>fork</i>, Tyler." 
#
# == Getting More Detailed
#
# If you can't find a method here that does what you need, you may need to
# loop through the elements and find a method in Hpricot::Container::Trav
# which can do what you need.
#
# For example, you may want to search for all the H3 header tags in a document
# and grab all the tags underneath the header, but not inside the header.
# A good method for this is <tt>next_sibling</tt>:
#
#   doc.search("h3").each do |h3|
#     while ele = h3.next_sibling
#       ary << ele   # stuff away all the elements under the h3
#     end
#   end
#
# Most of the useful element methods are in the mixins Hpricot::Traverse
# and Hpricot::Container::Trav.
  class Elements < Array
    # Searches this list for any elements (or children of these elements) matching
    # the CSS or XPath expression +expr+.  Root is assumed to be the element scanned.
    #
    # See Hpricot::Container::Trav.search for more.
    def search(*expr,&blk)
      Elements[*map { |x| x.search(*expr,&blk) }.flatten.uniq]
    end
    alias_method :/, :search

    # Searches this list for the first element (or child of these elements) matching
    # the CSS or XPath expression +expr+.  Root is assumed to be the element scanned.
    #
    # See Hpricot::Container::Trav.at for more.
    def at(expr, &blk)
      search(expr, &blk).first
    end
    alias_method :%, :at

    # Convert this group of elements into a complete HTML fragment, returned as a
    # string.
    def to_html
      map { |x| x.output("") }.join
    end
    alias_method :to_s, :to_html

    # Returns an HTML fragment built of the contents of each element in this list.
    #
    # If a HTML +string+ is supplied, this method acts like inner_html=.
    def inner_html(*string)
      if string.empty?
        map { |x| x.inner_html }.join
      else
        x = self.inner_html = string.pop || x
      end
    end
    alias_method :text, :inner_html
    alias_method :html, :inner_html
    alias_method :innerHTML, :inner_html

    # Replaces the contents of each element in this list.  Supply an HTML +string+,
    # which is loaded into Hpricot objects and inserted into every element in this
    # list.
    def inner_html=(string)
      each { |x| x.inner_html = string }
    end
    alias_method :html=, :inner_html=
    alias_method :innerHTML=, :inner_html=

    # Remove all elements in this list from the document which contains them.
    #
    #   doc = Hpricot("<html>Remove this: <b>here</b></html>")
    #   doc.search("b").remove
    #   doc.to_html
    #     => "<html>Remove this: </html>"
    #
    def remove
      each { |x| x.parent.children.delete(x) }
    end

    # Empty the elements in this list, by removing their insides.
    #
    #   doc = Hpricot("<p> We have <i>so much</i> to say.</p>")
    #   doc.search("i").empty
    #   doc.to_html
    #     => "<p> We have <i></i> to say.</p>"
    #
    def empty
      each { |x| x.inner_html = nil }
    end

    # Add to the end of the contents inside each element in this list.
    # Pass in an HTML +str+, which is turned into Hpricot elements.
    def append(str)
      each { |x| x.inner_html += str }
    end

    # Add to the start of the contents inside each element in this list.
    # Pass in an HTML +str+, which is turned into Hpricot elements.
    def prepend(str)
      each { |x| x.inner_html = str + x.inner_html }
    end
 
    # Add some HTML just previous to each element in this list.
    # Pass in an HTML +str+, which is turned into Hpricot elements.
    def before(str)
      each { |x| x.parent.insert_before Hpricot.make(str), x }
    end

    # Just after each element in this list, add some HTML.
    # Pass in an HTML +str+, which is turned into Hpricot elements.
    def after(str)
      each { |x| x.parent.insert_after Hpricot.make(str), x }
    end

    # Wraps each element in the list inside the element created by HTML +str+. 
    # If more than one element is found in the string, Hpricot locates the
    # deepest spot inside the first element.
    #
    #  doc.search("a[@href]").
    #      wrap(%{<div class="link"><div class="link_inner"></div></div>})
    #
    # This code wraps every link on the page inside a +div.link+ and a +div.link_inner+ nest.
    def wrap(str)
      each do |x|
        wrap = Hpricot.make(str)
        nest = wrap.detect { |w| w.respond_to? :children }
        unless nest
          raise Exception, "No wrapping element found."
        end
        x.parent.replace_child(x, wrap)
        nest = nest.children.first until nest.empty?
        nest.children << x
      end
    end

    # Sets an attribute for all elements in this list.  You may use
    # a simple pair (<em>attribute name</em>, <em>attribute value</em>):
    #
    #   doc.search('p').set(:class, 'outline')
    #
    # Or, use a hash of pairs:
    #
    #   doc.search('div#sidebar').set(:class => 'outline', :id => 'topbar')
    #
    def set(k, v = nil)
      case k
      when Hash
        each do |node|
          k.each { |a,b| node.set_attribute(a, b) }
        end
      else
        each do |node|
          node.set_attribute(k, v)
        end
      end
    end

    ATTR_RE = %r!\[ *(@)([a-zA-Z0-9\(\)_-]+) *([~\!\|\*$\^=]*) *'?"?([^'"]*)'?"? *\]!i
    BRACK_RE = %r!(\[) *([^\]]*) *\]!i
    FUNC_RE = %r!(:)([a-zA-Z0-9\*_-]*)\( *[\"']?([^ \)'\"]*)['\"]? *\)!
    CATCH_RE = %r!([:\.#]*)([a-zA-Z0-9\*_-]+)!

    def self.filter(nodes, expr, truth = true)
        until expr.empty?
            _, *m = *expr.match(/^(?:#{ATTR_RE}|#{BRACK_RE}|#{FUNC_RE}|#{CATCH_RE})/)
            break unless _

            expr = $'
            m.compact!
            if m[0] == '@'
                m[0] = "@#{m.slice!(2,1)}"
            end

            if m[0] == ":" && m[1] == "not"
                nodes, = Elements.filter(nodes, m[2], false)
            else
                meth = "filter[#{m[0]}]"
                if Container::Trav.method_defined? meth
                    args = m[1..-1]
                else
                    meth = "filter[#{m[0]}#{m[1]}]"
                    if Container::Trav.method_defined? meth
                        args = m[2..-1]
                    end
                end
                i = -1
                nodes = Elements[*nodes.find_all do |x| 
                                      i += 1
                                      x.send(meth, *([*args] + [i])) ? truth : !truth
                                  end]
            end
        end
        [nodes, expr]
    end

    def filter(expr)
        nodes, = Elements.filter(self, expr)
        nodes
    end

    def not(expr)
        if expr.is_a? Container::Trav
            nodes = self - [expr]
        else
            nodes, = Elements.filter(self, expr, false)
        end
        nodes
    end

    private
    def copy_node(node, l)
        l.instance_variables.each do |iv|
            node.instance_variable_set(iv, l.instance_variable_get(iv))
        end
    end

  end

  module Container::Trav
    def self.filter(tok, &blk)
      define_method("filter[#{tok.is_a?(String) ? tok : tok.inspect}]", &blk)
    end

    filter '' do |name,i|
      name == '*' || self.name.downcase == name.downcase
    end

    filter '#' do |id,i|
      get_attribute('id').to_s == id
    end

    filter '.' do |name,i|
      classes.include? name
    end

    filter :lt do |num,i|
      self.position < num.to_i
    end

    filter :gt do |num,i|
      self.position > num.to_i
    end

    nth = proc { |num,i| self.position == num.to_i }
    nth_first = proc { |num,i| self.position == 0 }
    nth_last = proc { |num| self == parent.containers_of_type(self.name).last }

    filter :nth, &nth
    filter :eq, &nth
    filter ":nth-of-type", &nth

    filter :first, &nth_first
    filter ":first-of-type", &nth_first

    filter :last, &nth_last
    filter ":last-of-type", &nth_last

    filter :even do |num,i|
      self.position % 2 == 0
    end

    filter :odd do |num,i|
      self.position % 2 == 1
    end

    filter ':first-child' do |i|
      self == parent.containers.first
    end

    filter ':nth-child' do |arg,i|
      case arg 
      when 'even'; parent.containers.index(self) % 2 == 0
      when 'odd';  parent.containers.index(self) % 2 == 1
      else         self == parent.containers[arg.to_i]
      end
    end

    filter ":last-child" do |i|
      self == parent.containers.last
    end
    
    filter ":nth-last-child" do |arg,i|
      self == parent.containers[-1-arg.to_i]
    end

    filter ":nth-last-of-type" do |arg,i|
      self == parent.containers_of_type(self.name)[-1-arg.to_i]
    end

    filter ":only-of-type" do |arg,i|
      parent.containers_of_type(self.name).length == 1
    end

    filter ":only-child" do |arg,i|
      parent.containers.length == 1
    end

    filter :parent do
      childNodes.length > 0
    end

    filter :empty do
      childNodes.length == 0
    end

    filter :root do
      self.is_a? Hpricot::Doc
    end
    
    filter :contains do |arg,|
      html.include? arg
    end

    filter '@=' do |attr,val,i|
      get_attribute(attr).to_s == val
    end

    filter '@!=' do |attr,val,i|
      get_attribute(attr).to_s != val
    end

    filter '@~=' do |attr,val,i|
      get_attribute(attr).to_s.split(/\s+/).include? val
    end

    filter '@|=' do |attr,val,i|
      get_attribute(attr).to_s =~ /^#{Regexp::quote val}(-|$)/
    end

    filter '@^=' do |attr,val,i|
      get_attribute(attr).to_s.index(val) == 0
    end

    filter '@$=' do |attr,val,i|
      get_attribute(attr).to_s =~ /#{Regexp::quote val}$/
    end

    filter '@*=' do |attr,val,i|
      idx = get_attribute(attr).to_s.index(val)
      idx >= 0 if idx
    end

    filter '@' do |attr,val,i|
      has_attribute? attr
    end

    filter '[' do |val,i|
      search(val).length > 0
    end

  end
end
