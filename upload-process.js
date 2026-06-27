const imageInput = document.getElementById('imageInput');
const attachmentInput = document.getElementById('attachmentInput');
const btSubmit = document.getElementById('btSubmit')
const imageContainer_s = document.getElementById('imageContainer_s')
const uploadedFilenames = document.getElementById('uploadedFilenames')

const title = document.getElementById('title')
const content = document.getElementById('content')
const author = document.getElementById('author')

async function uploadInit() {
  let autoSignature = await ConfigDB.get('autoSignature')
  if (autoSignature) {
    if (autoSignature.value === 'true') {
      const autoSignatureContent = await ConfigDB.get('autoSignatureContent')
      if (autoSignatureContent) { author.value = autoSignatureContent.content }
    }
  }
}
uploadInit()

var fileState = true;
var titleState = false;

var titleValue = title.value;


let attachmenStatus = false; //检测附件是否正常上传
let checkStatus = false; //检测上传内容是否合规

const uploadPhpUrl = 'https://tree.leisure.xin/node/file-processor/upload';
const uploadUrl = 'https://tree.leisure.xin/node/posts';

function limitPrompt(message) {
  const span = document.createElement('span')
  span.id = "limitPrompt";
  span.textContent = message;
  imageContainer_s.appendChild(span)
  btSubmit.textContent = ("拒绝");
  btSubmit.id = "btSubmitNo";
  return;
}

function checkUploads() {
  attachmenStatus = false;
  checkStatus = false
  imageContainer_s.innerHTML = '';
  btSubmit.textContent = ("发布");
  btSubmit.id = "btSubmit";
  if (attachmentInput.files.length) {
    if (attachmentInput.files[0].size / 1024 / 1024 > 3.5) {
      limitPrompt("!经典长篇小说:列夫·托尔斯泰的《战争与和平》纯文本大小仅3.5mb，而你我的朋友，你上传了一个" + (attachmentInput.files[0].size / 1024 / 1024).toFixed(2) + "mb的纯文字文件");
      attachmenStatus = true;
    }
    else checkStatus = true;
  }

  if (attachmenStatus) {
    return;
  }

  if (imageInput.files.length) {
    let imageSize = 0;
    let imageContainer = imageInput.files;
    checkStatus = false;
    if (imageContainer.length > 12) {
      limitPrompt("!上传的图像过多，上限为12张");
    }
    else {
      for (const image of imageContainer) {
        imageSize += (image.size / 1024 / 1024);
      } if (imageSize > 8.3) {
        limitPrompt("!上传的图像过大，最大为8mb");
      } else {
        checkStatus = true;

        //pre-view
        var imageID = 0;
        for (const image of imageContainer) {
          const filename = image.name;
          const reader = new FileReader();

          reader.onload = (e) => {
            const container = document.createElement('div')
            container.id = imageID;
            container.className = 'image_container';
            imageContainer_s.appendChild(container)
            const container_ = document.getElementById(imageID)
            imageID += 1;
            const img = document.createElement('img');
            img.src = e.target.result;
            img.className = 'image_preview';
            img.alt = 'preview image';
            img.id = filename;
            container_.appendChild(img);

            img.onload = () => {
              const imagePreview = document.getElementById(filename);
              const prompt = document.createElement('span');

              prompt.className = 'image_upload_prompt';
              prompt.id = "pro" + filename;
              prompt.style.marginLeft = - imagePreview.clientWidth + 'px'
              if (89 < imagePreview.clientWidth) {
                prompt.textContent = 'uploading...';
              } else {
                prompt.textContent = 'load..';
              }
              container_.appendChild(prompt);
            }
          };
          reader.readAsDataURL(image);
        }
      }
    }
  }
}

async function fetchUpload(type, file) {
  const formData = new FormData();
  formData.append('type', type);
  formData.append('file', file)
  const res = await fetch(uploadPhpUrl, {
    method: 'POST',
    body: formData
  });
  if (!res.ok) {
    alert('上传失败, 请稍后再试');
    return;
  }
  const data = await res.json();
  if (type === 'image') {
    const loadedFile = document.getElementById(file.name);
    loadedFile.className = "image_loaded"
    const loadedPrompt = document.getElementById("pro" + file.name);
    loadedPrompt.style.display = 'none';
  }
  return {
    type: type,
    original: data.originalName,
    filename: data.filename
  };
}

async function preUpload() {
  fileState = false;
  const promises = [];
  const imageContainer = imageInput.files;
  if (attachmentInput.files.length) {
    promises.push(fetchUpload("attachment", attachmentInput.files[0]))
  }
  if (imageInput.files.length) {
    for (const image of imageContainer) {
      promises.push(fetchUpload("image", image));
    }
  }
  try {
    const uploadedNames = await Promise.all(promises);
    uploadedFilenames.value = JSON.stringify(uploadedNames);
  } catch (err) {
    uploadedFilenames.value = '';
    limitPrompt("!上传失败，请重试")
  }
}

function sumbitShow() {
  if (titleState && fileState) {
    btSubmit.textContent = ("发布");
    btSubmit.id = "btSubmitOK";
  } else {
    btSubmit.textContent = ("发布");
    btSubmit.id = "btSubmit";
  }
}

title.addEventListener('change', function () {
  title.value != "" ? titleState = true : titleState = false;
  sumbitShow()
})

attachmentInput.addEventListener('change', async function () {
  fileState = false;
  btSubmit.textContent = ("发布");
  btSubmit.id = "btSubmit";
  checkUploads();
  if (checkStatus) {
    await preUpload()
    fileState = true;
  }
  else {
    fileState = false;
  }
  sumbitShow()
});
imageInput.addEventListener('change', async function () {
  fileState = false;
  btSubmit.textContent = ("发布");
  btSubmit.id = "btSubmit";
  checkUploads();
  if (checkStatus) {
    await preUpload()
    fileState = true;
  }
  else {
    fileState = false;
  }
  sumbitShow()
});

btSubmit.addEventListener('click', async function () {
  if (btSubmit.id != "btSubmitOK") {
    return;
  }
  let uploadedArray = []
  if (uploadedFilenames.value) {
    uploadedArray = JSON.parse(uploadedFilenames.value);
  }
  const postData = {
    title: title.value,
    content: content.value,
    author: author.value,
    uploaded: uploadedArray
  };
  window.location.replace("https://tree.leisure.xin/square/")
  try {
    const res = await fetch(uploadUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(postData)
    });
    if (res.ok) {
      const post = await res.json()
      let autoAddTipFormToPosts = await ConfigDB.get('autoAddTipFormToPosts')
      if (autoAddTipFormToPosts.value === "true") {
        await PostDB.put({ postId: post.id, title: post.title, author: post.author, lastUpdated: post.update_at })
      };
    }
  } catch (error) {
    alert('发布失败' + error)
  }
})
