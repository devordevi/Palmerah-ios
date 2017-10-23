//
//  ChatRoomView.swift
//  Palmerah
//
//  Created by Bobby Prabowo on 19/10/17.
//  Copyright © 2017 Bobby Adi Prabowo. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class ChatRoomView : UICollectionView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UITextViewDelegate {
 
    private let cellId  = "cellId"
    
    private let maxBubbleContentWidth = 250
    private let textPadding = CGFloat(10)
    private let sideBubblePadding = CGFloat(10)
    private let topBubblePadding = CGFloat(5)
    private let bottomBubblePadding = CGFloat(10)
    private let senderBubbleColor = UIColor.appleBlue()
    private let receiverBubbleColor = UIColor(white: 0.95, alpha: 1)
    
    var viewModel : ChatRoomViewModel? = nil
    private var disposeBag = CompositeDisposable()
    private var messageInputView : MessageInputView? = MessageInputView()
    private var blockOperations = [BlockOperation]()
    
    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        super.init(frame: frame, collectionViewLayout: layout)
        self.messageInputView?.inputTextView.delegate = self
        let inputDisposable = self.messageInputView?.sendMessageButton.rx.tap.asDriver()
            .map { [weak self] _ in self?.messageInputView?.inputTextView.text ?? "" }
            .filter { text in !text.isEmpty }
            .filter { [weak self] text in (self?.viewModel?.insertMessage(textMessage: text))! }
            .map { _ in "" }
            .drive((self.messageInputView?.inputTextView.rx.text)!)
        
        disposeBag.insert(inputDisposable!)
        
        self.contentInsetAdjustmentBehavior = .automatic
        self.showsHorizontalScrollIndicator = false;
        self.backgroundColor = .white
        self.alwaysBounceVertical = true
        self.register(ChatCell.self, forCellWithReuseIdentifier: cellId)
        self.keyboardDismissMode = .interactive
        self.dataSource = self
        self.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardEvent), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func handleKeyboardEvent(_ notification: Notification) {
        let keyboardFrame = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as AnyObject).cgRectValue
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.2, animations: {
                self.contentInset.bottom = (keyboardFrame?.height)!
            })
            self.scrollToBottom(animated: true);
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var inputAccessoryView: UIView? {
        return messageInputView
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return (self.viewModel?.messagesCount())!
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as? ChatCell
        let message = self.viewModel?.messageAt(indexPath: indexPath)
        
        if let textMessage = message?.text {
            cell?.messageWithTimestampView.messageLabel.text = message?.text
            
            let messageTextSize = textMessage.frameSize(maxWidth: CGFloat(maxBubbleContentWidth), font: UIFont.preferredFont(forTextStyle: .body))
            
            var totalHeight = messageTextSize.height + (2 * textPadding)
            let totalWidth = messageTextSize.width + (2 * textPadding)
            var startBubble : CGFloat?;
            
            if (message?.isSender)! {
                cell?.messageWithTimestampView.messageLabel.textColor = UIColor.white
                startBubble = self.frame.width - (messageTextSize.width + ( 2 * textPadding ) + sideBubblePadding)
            } else {
                cell?.messageWithTimestampView.messageLabel.textColor = UIColor.black
                startBubble = sideBubblePadding
            }
            
            cell?.messageWithTimestampView.messageLabel.frame = CGRect(x: startBubble! + textPadding, y: topBubblePadding + textPadding, width: messageTextSize.width, height: messageTextSize.height)
            
            if let timestampMessage = message?.date {
                
                let timestampText = formatDate(date: timestampMessage)
                
                let timestampTextSize = timestampText.frameSize(maxWidth: CGFloat(maxBubbleContentWidth), font: UIFont.preferredFont(forTextStyle: .footnote))
                
                cell?.messageWithTimestampView.timestampLabel.text = timestampText
                
                if (message?.isSender)! {
                    cell?.messageWithTimestampView.timestampLabel.textColor = UIColor.white
                } else {
                    cell?.messageWithTimestampView.timestampLabel.textColor = UIColor.black
                }
                
                cell?.messageWithTimestampView.timestampLabel.frame = CGRect(
                    x: (cell?.messageWithTimestampView.messageLabel.frame.maxX)! - timestampTextSize.width,
                    y: (cell?.messageWithTimestampView.messageLabel.frame.maxY)! + textPadding,
                    width: timestampTextSize.width,
                    height: timestampTextSize.height
                )
                
                totalHeight +=  timestampTextSize.height + textPadding
            }
            
            if (message?.isSender)! {
                cell?.bubbleBackgroundView.backgroundColor = senderBubbleColor
            } else {
                cell?.bubbleBackgroundView.backgroundColor = receiverBubbleColor
            }
            
            cell?.bubbleBackgroundView.frame = CGRect(x: startBubble!, y: topBubblePadding, width: totalWidth, height: totalHeight)
            
        }
        
        return cell!
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var totalHeight : CGFloat = 0.0
        let currentMessage = self.viewModel?.messageAt(indexPath: indexPath)
        
        if let textMessage = currentMessage?.text {
            
            let messageTextSize = textMessage.frameSize(maxWidth: CGFloat(maxBubbleContentWidth), font: UIFont.preferredFont(forTextStyle: .body))
            
            var bubbleSpace = bottomBubblePadding;
            if (indexPath.item < ((self.viewModel?.messagesCount())! - 1)) {
                let currentBubbleSender = currentMessage?.isSender
                let nextIndex = IndexPath(item: indexPath.item + 1, section: indexPath.section)
                let nextMessage = self.viewModel?.messageAt(indexPath: nextIndex)
                if (currentBubbleSender == nextMessage?.isSender) {
                    bubbleSpace = 0
                }
            }
            totalHeight = messageTextSize.height + (2 * textPadding) + topBubblePadding + bubbleSpace;
            
            if let timestampMessage = currentMessage?.date {
                
                let timestampText = formatDate(date: timestampMessage)
                
                let timestampTextSize = timestampText.frameSize(maxWidth: CGFloat(maxBubbleContentWidth), font: UIFont.preferredFont(forTextStyle: .footnote))

                totalHeight += timestampTextSize.height + textPadding
            }
            
        }
        
        return CGSize(width: self.frame.width, height: totalHeight)
    }
    
    func scrollToBottom(animated: Bool) {
        let lastMessageIndexPath = IndexPath(item: (self.viewModel?.messagesCount())! - 1, section: 0)
        self.scrollToItem(at: lastMessageIndexPath, at: .bottom, animated: animated)
        
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        
        messageInputView?.inputTextViewLabelPlaceHolder.isHidden = textView.hasText
        if ((self.viewModel?.messagesCount())! > 0) {
            DispatchQueue.main.async(execute: {
                self.scrollToBottom(animated: true)
            })
            
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        messageInputView?.inputTextViewLabelPlaceHolder.isHidden = textView.hasText
    }
    
    func onBind() {
        let rowDisposable = self.viewModel?.rowUpdateSubject.subscribe(onNext: { [weak self] (event) in
            switch event.type {
            case .insert:
                self?.blockOperations.append(BlockOperation(block: { [weak self] in
                    self?.insertItems(at: [event.newIndexPath!])
                }))
                break
            case .delete:
                self?.blockOperations.append(BlockOperation(block: { [weak self] in
                    self?.deleteItems(at: [event.indexPath!])
                }))
                break
            case .update:
                self?.blockOperations.append(BlockOperation(block: { [weak self] in
                    self?.reloadItems(at: [event.indexPath!])
                }))
                break
            default:
                break
            }
        }, onError: { (error) in
            
        }, onCompleted: {
            
        }, onDisposed: {
            
        })
        
        disposeBag.insert(rowDisposable!)
        
        let changeDisposable = self.viewModel?.changeContentSubject.subscribe(onNext: { [weak self] (result) in
            DispatchQueue.main.async {
                self?.performBatchUpdates({
                    for operation in (self?.blockOperations)! {
                        operation.start()
                    }
                }, completion: { (completed) in
                    self?.scrollToBottom(animated: true)
                })
            }
        }, onError: { (error) in
            
        }, onCompleted: {
            
        }, onDisposed: {
            
        })
        
        disposeBag.insert(changeDisposable!)
        
    }

    func adjustBottomInset() {
        self.contentInset.bottom = (messageInputView?.frame.height)!
    }
    
    func formatDate(date: NSDate) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm a"
        
        let elapsedTimeInSecond : TimeInterval = NSDate().timeIntervalSince(date as Date)
        let oneDayInSeconds : TimeInterval = 60 * 60 * 24
        let oneWeekInSeconds : TimeInterval = 7 * oneDayInSeconds
        
        if elapsedTimeInSecond > oneDayInSeconds {
            dateFormatter.dateFormat = "EEE"
        } else if elapsedTimeInSecond > oneWeekInSeconds {
            dateFormatter.dateFormat = "DD:MM"
        }
        
        let timestampText = dateFormatter.string(from: date as Date)
        return timestampText
    }
}