import { Entity, Column, Index, PrimaryGeneratedColumn, CreateDateColumn, OneToMany } from 'typeorm';
import { AttachmentEntity } from './attachment.entity'
import { ImageEntity } from './image.entity'
import { CommentEntity } from './comment.entity'

@Entity('posts')
export class PostEntity {
  @PrimaryGeneratedColumn({ type: 'int', name: 'id' })
  id: number;

  @Column({ type: 'varchar', length: 255 })
  title: string;

  @Column({ type: 'text', nullable: true, default: null })
  content: string;

  @Index('idx_author')
  @Column({ type: 'varchar', length: 100, nullable: true, default: null })
  author: string;

  @Index('idx_author_token')
  @Column({ type: 'varchar', length: 64, nullable: true, default: null, name: 'author_token' })
  author_token: string;

  @Column({
    type: 'int',
    name: 'reply_times',
    default: 0,
    comment: '评论/回复次数'
  })
  reply_times: number;

  @CreateDateColumn({
    type: 'timestamp',
    name: 'created_at'
  })
  created_at: Date;

  @Column({
    type: 'timestamp',
    name: 'update_at',
    default: '2000-01-01 00:00:00',
  })
  update_at: Date;

  @OneToMany(() => AttachmentEntity, (attachment) => attachment.post)
  attachments: AttachmentEntity[];

  @OneToMany(() => ImageEntity, (image) => image.post)
  images: ImageEntity[];

  @OneToMany(() => CommentEntity, (comment) => comment.post)
  comments: CommentEntity[];
}
