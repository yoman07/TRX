/**
 
 Agregates multiple Tweenables.
 Use a Timelines to chain Tweens or even other Timelines.
 
 */
final public class TimeLine: AbstractTweenable, Tweenable, ArrayLiteralConvertible, DictionaryLiteralConvertible {
  
  //MARK: nested
  
  public typealias UpdateClosure = () -> ()
  
  private struct Span {
    var start: NSTimeInterval
    var end: NSTimeInterval
    
    func contains(time: NSTimeInterval) -> Bool {
      return start <= time && time < end
    }
  }
  
  private struct TweenContainer {
    var tween: Tweenable
    var span: Span
    
    func scaled(value: Double) -> TweenContainer {
      tween.scale = value
      return TweenContainer(tween: tween,
                            span: Span(start: span.start * value,
                                       end: span.end * value))
    }
  }
  
  //MARK: properties

  private var container = [TweenContainer]()
  var onUpdate: UpdateClosure?
  
  //MARK: initializers
  
  /**
   
   Creates new TimeLine
   
   - Parameter tweens: An array of Tweenables
   
   */
  public init(tweens: [Tweenable]) {
    super.init()
    tweens.forEach { add($0) }
    moveToStart();
  }
  
  /**
   
   Creates new TimeLine
   
   */
  public override init() {
    super.init()
  }
  
  /**
   
   Creates new TimeLine from a literal array
   
   */
  public convenience init(arrayLiteral elements: Tweenable...) {
    self.init(tweens: elements)
  }
  
  /**
   
   Creates new TimeLine from a literal dictionary
   
   */
  public init(dictionaryLiteral elements: (Tweenable, Double)...) {
    super.init()
    elements.forEach { add($0.0, shift: $0.1) }
    self.moveToStart();
  }
  
  //MARK: lifecycle
  
  private func moveToStart() {
    container.filter { return $0.span.contains(0) }
    .forEach { ($0.tween as? Updatable)?.update() }
  }
  
  /// Current time offset (seconds)
  override public var head: NSTimeInterval {
    didSet {
      update(head, prevHead: oldValue)
    }
  }
  
  private func update(head: NSTimeInterval, prevHead: NSTimeInterval) {
    
    var deffered: [() -> ()] = []
    container.forEach { data in
      let tweenable = data.tween
      let span = data.span
      let distance = span.start.distanceTo(head)
      let distanceTo = min(max(0, distance), tweenable.duration)
      if !paused && pointPassed(head, prevDelta: prevHead, point: span.start) {
        tweenable.onStart?()
      }
      if distanceTo == distance {
        deffered.append({
          tweenable.seek(distanceTo)
        })
      } else {
        tweenable.seek(distanceTo)
      }
      if !paused && pointPassed(head, prevDelta: prevHead, point: span.end) {
        tweenable.onComplete?(done: true)
      }
    }
    deffered.forEach { $0() }
  }
  
  private func pointPassed(delta: NSTimeInterval, prevDelta: NSTimeInterval, point: NSTimeInterval) -> Bool {
    return  delta == point || (delta > point && prevDelta < point)
  }
  
  //MARK: collection
  
  /// contained Tweeenables
  public var tweens: [Tweenable] {
    return container.map { $0.tween }
  }
  
  /**
   
   Add a Tweenable to Timeline
   
   - Parameter tween: Tweenable
   - Parameter shift: Delta to previous Tweenable (in seconds); defaults to 0
   
   */
  public func add(tween: Tweenable, shift: NSTimeInterval = 0.0) {
    let start = duration + shift
    let end = start + tween.duration
    let data = TweenContainer(tween: tween,
                              span: Span(start: start, end: end))
    if let subscriber = tween as? Subscriber {
      keys.unionInPlace(subscriber.keys)
    }
    container.append(data)
  }
  
  /**
   Add an array of Tweenables to Timeline
   
   - Parameter tweens: Array of Tweenables
  */
  public func add(tweens: [Tweenable]) {
     tweens.forEach { add($0) }
  }
  
  //MARK: time
  
  /// Duration (seconds)
  override public var duration: NSTimeInterval {
    get {
      return container.map({ $0.span.end }).maxElement() ?? 0
    }
    set {
      scale = newValue / duration
    }
  }
  
  /// Scale. Defaults to 1.0
  public var scale: Double = 1.0 {
    didSet {
      container = container.map { $0.scaled(scale) }
    }
  }
  
}
