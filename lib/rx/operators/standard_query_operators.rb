# Copyright (c) Microsoft Open Technologies, Inc. All rights reserved. See License.txt in the project root for license information.

require 'rx/concurrency/current_thread_scheduler'
require 'rx/concurrency/immediate_scheduler'
require 'rx/core/observer'
require 'rx/subscriptions/composite_subscription'
require 'rx/subscriptions/subscription'

module RX

  module Observable

    # Standard Query Operators

    # Returns the elements of the specified sequence or the type parameter's default value in a singleton sequence if the sequence is empty.
    def default_if_empty(default_value)
      AnonymousObservable.new do |observer|
        found = false
        new_observer = Observer.configure do |o|
          
          o.on_next do |x|
            found = true
            observer.on_next x
          end

          o.on_error &observer.method(:on_error)

          o.on_completed do 
            observer.on_next(default_value) unless found
            observer.on_completed
          end
        end

        subscribe(new_observer)
      end
    end

    # Returns an observable sequence that contains only distinct elements according to the optional key_selector.
    def distinct(&key_selector)
      key_selector ||= lambda {|x| x}

      AnonymousObservable.new do |observer|

        h = Hash.new

        new_observer = Observer.configure do |o|

          o.on_next do |x|
            key = nil
            has_added = false

            begin
              key = key_selector.call x
              key_s = key.to_s
              unless h.key? key_s
                has_added = true
                h[key_s] = true
              end
            rescue => e
              observer.on_error e
              next
            end

            observer.on_next x if has_added
          end

          o.on_error &observer.method(:on_error)
          o.on_completed &observer.method(:on_completed)
        end

        subscribe(new_observer)
      end
    end

    # Projects each element of an observable sequence into a new form by incorporating the element's index.
    def map_with_index(&block)
      AnonymousObservable.new do |observer|
        new_observer = Observer.configure do |o|
          i = 0

          o.on_next do |x|
            result = nil
            begin
              result = block.call(x, i)
              i += 1
            rescue => e
              observer.on_error e
              next
            end

            observer.on_next result
          end

          o.on_error &observer.method(:on_error)
          o.on_completed &observer.method(:on_completed)          
        end

        subscribe(new_observer)
      end
    end

    # Projects each element of an observable sequence into a new form.
    def map(&block)
      map_with_index {|x, _| block.call x }
    end

    # Projects each element of the source observable sequence to the other observable sequence and merges the resulting observable sequences into one observable sequence.
    def flat_map(&block)
      map(&block).merge_all
    end

    # Projects each element of an observable sequence to an observable sequence by incorporating the element's index and merges the resulting observable sequences into one observable sequence.
    def flat_map_with_index(&block)
      map_with_index(&block).merge_all
    end

    # Bypasses a specified number of elements in an observable sequence and then returns the remaining elements.
    def skip(count)
      AnonymousObservable.new do |observer|
        remaining = count

        new_observer = Observer.configure do |o|

          o.on_next do |x|
            if remaining <= 0
              observer.on_next x
            else 
              remaining -= 1
            end
          end

          o.on_error &observer.method(:on_error)
          o.on_completed &observer.method(:on_completed)  
        end


        subscribe(new_observer)
      end
    end

    # Bypasses elements in an observable sequence as long as a specified condition is true and then returns the remaining elements.
    def skip_while(&block)
      skip_while_with_index {|x, _| block.call x }
    end

    # Bypasses elements in an observable sequence as long as a specified condition is true and then returns the remaining elements.
    # The element's index is used in the logic of the predicate function.
    def skip_while_with_index(&block)
      AnonymousObservable.new do |observer|
        running = false
        i = 0

        new_observer = Observer.configure do |o|

          o.on_next do |x|
            unless running
              begin
                running = !block.call(x, i)
                i += 1
              rescue => e
                observer.on_error e
                next
              end

              observer.on_next x if running
            end
          end

          o.on_error &observer.method(:on_error)
          o.on_completed &observer.method(:on_completed)  
        end

        subscribe(new_observer)
      end
    end

    # Returns a specified number of contiguous elements from the start of an observable sequence.
    def take(count, scheduler = ImmediateScheduler.instance)
      return Observable.empty(scheduler) if count == 0

      AnonymousObservable.new do |observer|

        remaining = count

        new_observer = Observer.configure do |o|

          o.on_next do |x|
            if remaining > 0
              remaining -= 1
              observer.on_next x
              observer.on_completed if remaining == 0
            end
          end

          o.on_error &observer.method(:on_error)
          o.on_completed &observer.method(:on_completed)  
        end

        subscribe(new_observer)
      end
    end

    # Returns elements from an observable sequence as long as a specified condition is true.
    def take_while(&block)
      take_while_with_index {|x, _| block.call x }
    end

    # Returns elements from an observable sequence as long as a specified condition is true.
    # The element's index is used in the logic of the predicate function.
    def take_while_with_index(&block)
      AnonymousObservable.new do |observer|
        running = true
        i = 0

        new_observer = Observer.configure do |o|

          o.on_next do |x|
            if running
              begin
                running = block.call(x, i)
                i += 1
              rescue => e
                observer.on_error e
                next
              end

              if running
                observer.on_next x
              else
                observer.on_completed
              end
            end
          end

          o.on_error &observer.method(:on_error)
          o.on_completed &observer.method(:on_completed)  
        end

        subscribe(new_observer)
      end      
    end

    # Filters the elements of an observable sequence based on a predicate.
    def select(&block)
      select_with_index {|x, _| block.call x }
    end
    alias_method :find_all, :select

    # Filters the elements of an observable sequence based on a predicate by incorporating the element's index.
    def select_with_index(&block)
      AnonymousObservable.new do |observer|
        i = 0

        new_observer = Observer.configure do |o|

          o.on_next do |x|
            should_run = false
            begin
              should_run = block.call(x, i)
              i += 1
            rescue => e
              observer.on_error e
              next
            end

            observer.on_next x if should_run
          end

          o.on_error &observer.method(:on_error)
          o.on_completed &observer.method(:on_completed)  
        end

        subscribe(new_observer)        
      end
    end

    alias_method :find_all_with_index, :select_with_index
  end
end
