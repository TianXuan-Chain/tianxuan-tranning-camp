pragma solidity ^0.4.24;

import "./ERC721.sol";
/*
基础功能：
1、实现更换Owner(加分：考虑对方钱包的控制情况)
2、实现管理员给不同的人批量mint不同的nft接口
3、实现用户自己花钱购买的接口

升级功能：
1、实现白名单用户自己mint，实现批量增加白名单，白名单去重等功能
2、批量查询用户的资产

困难功能：
1、实现链下白名单的功能，就是链下通过签名的方式来提交白名单
2、链下定义价格，链上购买的方式

*/
contract Item is ERC721{
    
    struct GameItem{
        string name; // Name of the Item
        uint level; // Item Level
        uint rarityLevel;  // 1 = normal, 2 = rare, 3 = epic, 4 = legendary
    }
    
    GameItem[] public items; // First Item has Index 0
    address public owner;
    
    constructor () public {
        owner = msg.sender; // The Sender is the Owner; Ethereum Address of the Owner
        _whiteList.push(owner);
    }

    event ChangeOwner(
    address indexed oldOwner,
    address indexed newOwner
  );


  mapping (address => uint) private _isWhiteList;
  address [] private _whiteList;
  uint private tokenIdIndex = 1000;

    
    function createItem(string _name, address _to) public{//输入  sword,0xdbf8e2dbc4689b94b3eb57ed32e099d3ea4f0ef2
        require(owner == msg.sender); // Only the Owner can create Items
        uint id = items.length; // Item ID = Length of the Array Items
        items.push(GameItem(_name,5,1)); // Item ("Sword",5,1)
        _mint(_to,id); // Assigns the Token to the Ethereum Address that is specified
        //_mint 在ERC721.sol文件里面定义的
    }

    function changeOwner(address newOwner) public{//实现更换Owner(加分：考虑对方钱包的控制情况)
        //require
        require(owner == msg.sender); // 只有当前所有者可以更改所有者
        require(newOwner != address(0));
        emit ChangeOwner(owner, newOwner); // 触发 ChangeOwner 事件
        owner = newOwner;
    }

    function batchMintByOwner(address[] users, uint[] tokenIds) public{  //管理员给不同的人批量mint不同的nft接口
        require(owner == msg.sender);
        for (uint i = 0; i < users.length; i++) {
            uint id = tokenIds[i]; // 获取当前的 tokenId
            require(id >= tokenIdIndex, "Token ID must be greater than or equal to the starting index"); // 确保 tokenId 合法
            //require(id < items.length, "Token ID must be less than the number of items"); // 确保 tokenId 在有效范围内

            // Mint the token to the user
            _mint(users[i], id); // 将 token mint 给指定的用户
        }
    }

    function mint(uint _id) payable public{  //实现用户自己花钱购买的接口
        //require(_id >= tokenIdIndex && _id < tokenIdIndex + items.length,"nft tokenIds no exeit");
        require(_id >= tokenIdIndex && _id < tokenIdIndex + items.length, "NFT tokenId does not exist");
        uint price = 1 ether;
        require(msg.value >= price, "Insufficient funds sent");
        ownerOf(_id).transfer(msg.value); // 转账
        _removeTokenFrom(ownerOf(_id),_id);
        _mint(msg.sender, _id);

    }
 

    function mintByWhiteList(string _name, uint _level,uint _rarityLevel)  public{ //白名单用户自己mint
        //input sword,1,4  ,0xdbf8e2dbc4689b94b3eb57ed32e099d3ea4f0ef2
        //检查是否是白名单from
        bool flag=false;
        address _from = msg.sender;
        //if (keccak256(abi.encodePacked(address(_from))).length == 0) {
        //     _from = msg.sender; // set default value
        //}
        for (uint i = 0; i < _whiteList.length; i++){
            if(_from == _whiteList[i]){
                flag=true;
                break;
            }
        }
        require(flag==true,"you are not in the whiteList");
        uint id = items.length + tokenIdIndex;
        items.push(GameItem(_name,_level,_rarityLevel));
        _mint(_from,id);
    }

    //白名单批量添加
    function addWhiteList(address[] memory users)  public{//输入格式["0xdbf8e2dbc4689b94b3eb57ed32e099d3ea4f0ef2","..."]
        //_whiteList.push(users);//不允许将一个数组传递到一个数组里面
        //0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
        require(msg.sender == owner,"you are not owner");
        for (uint i = 0; i < users.length; i++) {
            require(_isWhiteList[users[i]] == 0, "Address is already in the whitelist.");
            _whiteList.push(users[i]);
            _isWhiteList[users[i]] = 1;
        }
    }
    //白名单批量去除
    function removeWhiteList(address[] users)  public{ 
        require(msg.sender == owner,"you are not owner");
        for (uint i = 0; i < users.length; i++) {
            //require(_isWhiteList[users[i]] == 1,"Address is not in the whitelist.");
            uint k = 0;
            while (k < _whiteList.length && _whiteList[k] != users[i]) {
                k++;
            }
            require(k < _whiteList.length, "Address not found in whitelist array.");
            //_whiteList[k] = _whiteList[_whiteList.length - 1]; // 将最后一个元素移动到要删除的元素的位置
            //_whiteList.pop();// 减少数组的大小,但是版本限制不能用
            _isWhiteList[users[i]] =  0;  
            _whiteList[k] =_whiteList[_whiteList.length-1];
            _whiteList[_whiteList.length - 1] = address(0);
           /* for (uint j = k; j < _whiteList.length - 1; j++) {
                _whiteList[j] = _whiteList[j + 1];
            }
            _whiteList[_whiteList.length - 1] = address(0); */// Set the last element to zero-address, effectively removing it.
        }
    }

    function whiteList()  public view returns (address[]) {  
        return _whiteList;
    }


    function owner(address user)   public view returns (uint[]){//批量查询用户的资产
        uint balance = balanceOf(user); // 获取用户拥有的 NFT 数量
        uint[] memory tokenIds = new uint[](balance); // 创建一个数组来存储 tokenId
        
        uint count = 0; // 计数器
        uint i = tokenIdIndex;
        uint max = tokenIdIndex + items.length;
        for (; i < max; i++) {
            if (ownerOf(i) == user) { // 检查每个 tokenId 的所有者
                tokenIds[count] = i ; // 将 tokenId 添加到数组中
                count++;
            }
        }

        // 返回用户拥有的 tokenId 数组
        return tokenIds;
    }
    //这部分代码实现都在removeWhiteList函数里面了
    //function remove(address user,uint index) internal returns(bool) {   
    //}
}
